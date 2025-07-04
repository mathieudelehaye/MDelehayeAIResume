import os
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any, Iterable
import asyncio
import json

# FastAPI imports
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# LangChain imports
from langchain.agents import initialize_agent, AgentType
from langchain.agents.tools import Tool
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferWindowMemory
from langchain.schema import Document
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_community.vectorstores.pgvector import PGVector
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.vectorstores.base import VectorStore
from langchain.embeddings.base import Embeddings

# Database and utilities
import structlog
from dotenv import load_dotenv
import asyncpg, ssl
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
import psycopg
from pgvector.psycopg import register_vector

# Load environment variables
load_dotenv()

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

class CustomPGVector(VectorStore):
    """Custom implementation using our existing cv_embeddings table."""
    
    def __init__(
        self,
        connection_string: str,
        embedding_function: Embeddings,
        collection_name: str = "cv_embeddings",
        pre_delete_collection: bool = False,
    ):
        """Initialize with connection to existing table."""
        self.connection_string = connection_string
        self.embedding_function = embedding_function
        self.collection_name = collection_name
        
        # Create SQLAlchemy engine
        self.engine = create_engine(connection_string)
        
        # Initialize psycopg connection with pgvector
        self.conn = psycopg.connect(connection_string)
        register_vector(self.conn)
        
    def add_texts(
        self,
        texts: Iterable[str],
        metadatas: Optional[List[dict]] = None,
        **kwargs: Any,
    ) -> List[str]:
        """Add text data to our existing table."""
        # Generate embeddings
        embeddings = self.embedding_function.embed_documents(list(texts))
        
        # Prepare metadata
        if not metadatas:
            metadatas = [{} for _ in texts]
            
        # Insert into our existing table using binary format
        with self.conn.cursor() as cur:
            ids = []
            for content, metadata, embedding in zip(texts, metadatas, embeddings):
                metadata_json = json.dumps(metadata)
                cur.execute(
                    """
                    INSERT INTO cv_embeddings (content, embedding, metadata)
                    VALUES (%s, %s::vector, %s::jsonb)
                    RETURNING id
                    """,
                    (content, embedding, metadata_json)
                )
                ids.append(cur.fetchone()[0])
            self.conn.commit()
            
        return [str(id_) for id_ in ids]
        
    def similarity_search(
        self,
        query: str,
        k: int = 4,
        **kwargs: Any,
    ) -> List[Document]:
        """Search for similar documents using cosine similarity."""
        # Generate embedding for query
        query_embedding = self.embedding_function.embed_query(query)
        
        # Search using pgvector's cosine similarity with binary format
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT content, metadata,
                       1 - (embedding <=> %s::vector) as similarity
                FROM cv_embeddings
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (query_embedding, query_embedding, k)
            )
            
            documents = []
            for content, metadata, similarity in cur.fetchall():
                documents.append(
                    Document(
                        page_content=content,
                        metadata=json.loads(metadata) if isinstance(metadata, str) else metadata
                    )
                )
                
        return documents

    @classmethod
    def from_texts(
        cls,
        texts: List[str],
        embedding: Embeddings,
        metadatas: Optional[List[dict]] = None,
        connection_string: Optional[str] = None,
        **kwargs: Any,
    ) -> VectorStore:
        """Create CustomPGVector from texts."""
        if not connection_string:
            connection_string = os.getenv("DATABASE_URL")
            
        instance = cls(
            connection_string=connection_string,
            embedding_function=embedding,
            **kwargs
        )
        
        instance.add_texts(texts=texts, metadatas=metadatas)
        return instance

    @classmethod
    def from_documents(
        cls,
        documents: List[Document],
        embedding: Embeddings,
        connection_string: str,
        **kwargs: Any,
    ) -> VectorStore:
        """Create CustomPGVector from documents."""
        texts = [d.page_content for d in documents]
        metadatas = [d.metadata for d in documents]
        
        return cls.from_texts(
            texts=texts,
            embedding=embedding,
            metadatas=metadatas,
            connection_string=connection_string,
            **kwargs
        )

    def __del__(self):
        """Close psycopg connection on cleanup."""
        if hasattr(self, 'conn'):
            self.conn.close()

# FastAPI app configuration
app = FastAPI(
    title="CV Chatbot API with LangChain Agents",
    description="Advanced AI chatbot using LangChain agents to answer questions about Mathieu Delehaye's CV",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for your specific domains in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class ChatMessage(BaseModel):
    message: str = Field(..., min_length=1, max_length=1000, description="User message to the chatbot")
    session_id: Optional[str] = Field(None, description="Session ID for conversation continuity")

class ChatResponse(BaseModel):
    response: str = Field(..., description="Chatbot response")
    session_id: str = Field(..., description="Session ID for this conversation")
    sources: Optional[List[str]] = Field(None, description="Sources used to generate the response")
    conversation_id: str = Field(..., description="Unique conversation identifier")

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    version: str

# CV content for the knowledge base
MATHIEU_CV_SECTIONS = [
    {
        "title": "Professional Summary",
        "content": """Mathieu Delehaye is a Software engineer with 10+ years of experience delivering robust, 
        high-performance systems across cybersecurity, embedded, health tech, and finance. Currently pursuing 
        a part-time MSc in Financial Mathematics at Queen Mary University of London to learn, gain exposure, 
        and transition into the quantitative finance industry, with a strong focus on high-frequency trading (HFT) 
        and asset management. Combining engineering rigour, real-time systems experience, and strong mathematical foundations. 
        Eligible to work in the UK."""
    },
    {
        "title": "Current Education",
        "content": """MSc Financial Mathematics (part-time), expected First-Class at Queen Mary University of London (2024 - 2026).
        Modules include: Mathematical Modelling in Finance, Advanced Derivatives Pricing and Risk Management (hedging, 
        diversification and mean-variance analysis, utility maximisation), Continuous-Time Models in Finance, 
        Financial Markets and Instruments, Machine Learning with Python, Neural Networks and Deep Learning, 
        C++ for Finance, Advanced Computing in Finance."""
    },
    {
        "title": "Recent Experience - Verimatrix",
        "content": """Senior Software Engineer (Cybersecurity) at Verimatrix (2021 – 2024) in UK.
        - Developed C/C++/Python protection tools with SQL for anti-tamper and obfuscation in client software (e.g., JPMorgan, Dolby)
        - Reduced runtime overhead by 50% with a lightweight security mode
        - Contributed to a client-facing React/Python Flask visualisation tool
        - Implemented anti-debugging protections on Android/Linux by bypassing kernel-level restrictions
        - Diagnosed low-level issues using gdb, pdb, Procmon, and Ghidra
        - Refactored Jenkins pipelines to support parallel builds, reducing build times by 25%"""
    },
    {
        "title": "Health Tech Experience - Metix Medical",
        "content": """Software Engineer (Digital Health) at Metix Medical (2020 – 2021) in UK.
        - Designed ECG digital filters in Python/Numpy/SciPy and implemented in embedded C for DSP
        - Developed C++/Qt software on Yocto Linux, aligned with ISO 13485 and UX specs"""
    },
    {
        "title": "Transportation Experience - Alstom",
        "content": """Software Engineering Consultant (Transportation) at Alstom via Abylsen (2019 – 2020) in Belgium.
        - Developed real-time signalling software in C and PLC (CODESYS) to improve train driver awareness and reduce operational incidents
        - Engineered automatic reconnection with the train's central computer and resolved TCP/CIP buffer overflow issues using Wireshark
        - Increased system robustness and reusability with shared libraries; implemented secure driver authentication using a C-based SHA-1 hashing library"""
    },
    {
        "title": "Finance and Government Experience - Smals",
        "content": """Project Manager (eGovernment, Finance) at Smals (2013 - 2019) in Belgium.
        - Developed Python/SQL tools for automating access to tax and income data
        - Managed projects for finance and healthcare; maintained SOAP services
        - Delivered citizen records to tax authorities and banks"""
    },
    {
        "title": "Embedded Systems Experience - Alpha Technologies",
        "content": """Embedded Software Engineer (Energy) at Alpha Technologies (2012 - 2013) in Belgium.
        - Built embedded C#/.NET systems with CAN and TCP for power monitoring
        - Designed load balancing algorithm that reduced energy loss by 15%"""
    },
    {
        "title": "Projects",
        "content": """FintechModeler (2023 – 2025): Python/Pandas/C++ app to price European options using 
        Black–Scholes and binomial models; GUI and REST API deployed on Azure. 
        Available at github.com/mathieudelehaye/FintechModeler"""
    },
    {
        "title": "Previous Education",
        "content": """MEng Electrical Engineering & Master in Management, 2:1 from University of Mons.
        Modules: Statistics, Signal Processing, Modern Physics, Electronic Systems, Computer Networks, Microeconomics. 
        Finance project: Statistical analysis of quality regulation impact on company ROA/ROS in R. 
        Electronic project: LCD scrolling message display using Xilinx Spartan FPGA and Verilog; debugged and optimised with logic analyser. 
        Dissertation: Unsupervised ML for tumour detection in medical imaging using K-means and transforms (Fourier, Cosine, Wavelet)."""
    },
    {
        "title": "Technical Skills",
        "content": """Programming Languages: Python (5 years), C++, Embedded C, C#, SQL, Bash, VBA/Excel, MATLAB, R
        Technologies: NumPy, Pandas, SciPy, Bluetooth, TCP/IP, CAN bus, Linux, DSP, real-time systems, 
        multithreading (pthreads, std::thread), Jenkins, Docker, Git, Kubernetes, AWS (EC2, S3), Azure, REST APIs, React, scikit-learn
        Tools: gdb, pdb, Procmon, Ghidra, Bloomberg Terminal
        Finance: statistical testing, mathematical modelling for finance, derivatives pricing, risk management
        Methodologies: Agile/Scrum, CI/CD pipelines
        Soft Skills: communication, problem-solving"""
    },
    {
        "title": "Languages and Certifications",
        "content": """Languages: English (C1), French (native), Dutch (intermediate)
        Certifications: Bloomberg BMC, ITIL Foundation"""
    },
    {
        "title": "Contact Information",
        "content": """Location: London, UK
        Email: mathieu.delehaye@gmail.com
        Phone: +44 7831 254 658
        LinkedIn: linkedin.com/in/mathieudelehaye
        GitHub: github.com/mathieudelehaye"""
    }
]

# Global variables for LangChain components
llm: Optional[ChatOpenAI] = None
embeddings: Optional[OpenAIEmbeddings] = None
vectorstore: Optional[CustomPGVector] = None
conversation_chains: Dict[str, ConversationalRetrievalChain] = {}
db_pool: Optional[asyncpg.Pool] = None

async def initialize_ai_components():
    """Initialize OpenAI, embeddings, and vector store"""
    global llm, embeddings, vectorstore
    
    try:
        # Initialize OpenAI LLM
        llm = ChatOpenAI(
            model="gpt-3.5-turbo",
            temperature=0.7,
            openai_api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Initialize embeddings
        embeddings = OpenAIEmbeddings(
            openai_api_key=os.getenv("OPENAI_API_KEY")
        )
        
        # Create documents from CV sections
        documents = []
        for section in MATHIEU_CV_SECTIONS:
            doc = Document(
                page_content=section["content"],
                metadata={"title": section["title"], "source": "cv"}
            )
            documents.append(doc)
        
        # Split documents for better retrieval
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=500,
            chunk_overlap=50,
            separators=["\n\n", "\n", ".", "!", "?", ",", " ", ""]
        )
        split_docs = text_splitter.split_documents(documents)
        
        # Initialize vector store with our custom implementation
        connection_string = os.getenv("DATABASE_URL")
        vectorstore = CustomPGVector.from_documents(
            documents=split_docs,
            embedding=embeddings,
            connection_string=connection_string
        )
        
        logger.info("AI components initialized successfully")
        
    except Exception as e:
        logger.error("Failed to initialize AI components", error=str(e))
        raise

def get_conversation_chain(session_id: str) -> ConversationalRetrievalChain:
    """Get or create conversation chain for a session"""
    if session_id not in conversation_chains:
        # Create memory for conversation
        memory = ConversationBufferWindowMemory(
            k=10,  # Remember last 10 exchanges
            memory_key="chat_history",
            return_messages=True,
            output_key="answer"
        )
        
        # Create the conversational retrieval chain
        chain = ConversationalRetrievalChain.from_llm(
            llm=llm,
            retriever=vectorstore.as_retriever(
                search_type="similarity",
                search_kwargs={"k": 4, "filter_duplicate_documents": True}
            ),
            memory=memory,
            return_source_documents=True,
            verbose=True
        )
        conversation_chains[session_id] = chain
    return conversation_chains[session_id]

@app.on_event("startup")
async def startup_event():
    """Initialize AI components on startup"""
    await initialize_ai_components()
    # Initialise Postgres connection pool (Neon)
    try:
        await init_db()
    except Exception as db_err:
        logger.error("Database init failed", error=str(db_err))

@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint"""
    return {
        "message": "CV Chatbot API with LangChain Agents",
        "version": "2.0.0",
        "docs": "/docs"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint that also verifies critical dependencies."""
    try:
        # Check if required environment variables are set
        assert os.getenv("OPENAI_API_KEY"), "OpenAI API key not configured"
        
        return HealthResponse(
            status="healthy",
            timestamp=datetime.utcnow(),
            version="2.0.0"
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

@app.post("/chat", response_model=ChatResponse)
async def chat_with_cv_bot(message: ChatMessage):
    """Main chat endpoint using LangChain agents"""
    try:
        # Generate session ID if not provided
        session_id = message.session_id or f"session_{datetime.utcnow().timestamp()}"
        
        # Get conversation chain for this session
        chain = get_conversation_chain(session_id)
        
        # Process the message using invoke instead of __call__
        result = await asyncio.to_thread(
            lambda: chain.invoke({"question": message.message})
        )
        
        # Extract sources with deduplication
        sources = []
        if "source_documents" in result:
            seen_titles = set()
            for doc in result["source_documents"]:
                title = doc.metadata.get("title", "CV Section")
                if title not in seen_titles:
                    sources.append(title)
                    seen_titles.add(title)
        
        # Log the interaction
        logger.info(
            "Chat interaction",
            session_id=session_id,
            question=message.message,
            response_length=len(result["answer"]),
            sources=sources
        )
        
        # Persist to database (best-effort)
        await log_interaction(session_id, message.message, result["answer"])
        
        return ChatResponse(
            response=result["answer"],
            session_id=session_id,
            sources=sources,
            conversation_id=session_id
        )
        
    except Exception as e:
        logger.error("Chat error", error=str(e), session_id=session_id)
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to process chat message: {str(e)}"
        )

@app.get("/sample-questions")
async def get_sample_questions():
    """Get sample questions for the chatbot"""
    return {
        "sample_questions": [
            "What is Mathieu's experience in cybersecurity?",
            "Tell me about Mathieu's education in financial mathematics",
            "What programming languages does Mathieu know best?",
            "Describe Mathieu's transition from engineering to finance",
            "What embedded systems experience does Mathieu have?",
            "Tell me about Mathieu's work at Verimatrix",
            "What machine learning projects has Mathieu worked on?",
            "How long has Mathieu been working in software engineering?",
            "What is the FintechModeler project?",
            "Describe Mathieu's experience with real-time systems"
        ]
    }

@app.post("/reset-session")
async def reset_session(session_id: str):
    """Reset a conversation session"""
    try:
        if session_id in conversation_chains:
            del conversation_chains[session_id]
            logger.info("Session reset", session_id=session_id)
            return {"message": f"Session {session_id} reset successfully"}
        else:
            return {"message": f"Session {session_id} not found"}
    except Exception as e:
        logger.error("Session reset error", error=str(e), session_id=session_id)
        raise HTTPException(status_code=500, detail="Failed to reset session")

@app.get("/active-sessions")
async def get_active_sessions():
    """Get list of active conversation sessions"""
    return {
        "active_sessions": list(conversation_chains.keys()),
        "count": len(conversation_chains)
    }

# -----------------------------
# Database (PostgreSQL / Neon)
# -----------------------------

async def init_db():
    """Create connection pool and ensure chat_logs table exists."""
    global db_pool
    if db_pool is not None:
        return  # Already initialised

    # Prefer full DATABASE_URL if provided (e.g. from Neon dashboard)
    db_url = os.getenv("DATABASE_URL")

    if not db_url:
        host = os.getenv("DB_HOST", "localhost")
        port = int(os.getenv("DB_PORT", 5432))
        user = os.getenv("DB_USER", "postgres")
        password = os.getenv("DB_PASSWORD", "password")
        db_name = os.getenv("DB_NAME", "cv_ai_logs")
        db_url = f"postgresql://{user}:{password}@{host}:{port}/{db_name}"

    ssl_mode = os.getenv("DB_SSL_MODE", "require").lower()
    ssl_context = None
    if ssl_mode == "require":
        ssl_context = ssl.create_default_context()

    db_pool = await asyncpg.create_pool(dsn=db_url, ssl=ssl_context, min_size=1, max_size=5)
    logger.info("PostgreSQL connection pool established")


async def log_interaction(session_id: str, question: str, answer: str):
    """Persist a single Q&A interaction to the database."""
    if db_pool is None:
        return  # DB not configured
    try:
        async with db_pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO chat_logs (session_id, question, answer) VALUES ($1, $2, $3)",
                session_id,
                question,
                answer,
            )
    except Exception as exc:
        logger.error("DB log error", error=str(exc))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        log_level="info",
        reload=True
    ) 