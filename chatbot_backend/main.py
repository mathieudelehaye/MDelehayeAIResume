import os
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any, Iterable
import asyncio
import json

# FastAPI imports
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# LangChain imports
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferWindowMemory
from langchain.schema import Document
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_core.vectorstores import VectorStore
from langchain_core.embeddings import Embeddings

# Database for CV embeddings (READ-ONLY)
import psycopg
from psycopg_pool import ConnectionPool
from pgvector.psycopg import register_vector

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Configure basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CustomPGVector(VectorStore):
    """Custom implementation for READ-ONLY access to existing cv_embeddings table."""
    
    def __init__(
        self,
        connection_string: str,
        embedding_function: Embeddings,
        collection_name: str = "cv_embeddings",
    ):
        """Initialize with READ-ONLY connection to existing CV embeddings table."""
        self.connection_string = connection_string
        self.embedding_function = embedding_function
        self.collection_name = collection_name
        
        # Create connection pool for READ-ONLY access
        conn_params = psycopg.conninfo.conninfo_to_dict(connection_string)
        self.pool = ConnectionPool(
            kwargs=conn_params,
            min_size=1,
            max_size=5,
            timeout=30.0,
            max_waiting=10.0,
            num_workers=2
        )
        
        # Register vector type
        with self.pool.connection() as conn:
            register_vector(conn)
        
    def add_texts(
        self,
        texts: Iterable[str],
        metadatas: Optional[List[dict]] = None,
        **kwargs: Any,
    ) -> List[str]:
        """Not implemented - READ-ONLY access to existing CV embeddings."""
        raise NotImplementedError("This vector store is READ-ONLY for CV embeddings")
        
    def similarity_search(
        self,
        query: str,
        k: int = 4,
        **kwargs: Any,
    ) -> List[Document]:
        """Search for similar documents using cosine similarity (READ-ONLY)."""
        # Generate embedding for query
        query_embedding = self.embedding_function.embed_query(query)
        
        # Search using pgvector's cosine similarity
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
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
    def from_documents(
        cls,
        documents: List[Document],
        embedding: Embeddings,
        connection_string: str,
        **kwargs: Any,
    ) -> VectorStore:
        """Create CustomPGVector with READ-ONLY access to existing CV embeddings."""
        return cls(
            connection_string=connection_string,
            embedding_function=embedding,
            **kwargs
        )

    def __del__(self):
        """Close connection pool on cleanup."""
        if hasattr(self, 'pool'):
            self.pool.close()

# FastAPI app
app = FastAPI(
    title="CV Chatbot API",
    description="AI-powered chatbot for Mathieu Delehaye's CV using LangChain with READ-ONLY database access",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Get allowed origins from environment or use defaults for local development
default_origins = [
    "http://localhost",
    "http://localhost:80",
    "http://127.0.0.1",
    "http://127.0.0.1:80",
    "http://192.168.0.62",
    "http://192.168.0.62:80",
]
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", ",".join(default_origins)).split(",")

# CORS configuration - Allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

# CV content for fallback (if database is unavailable)
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
        
        # Try to connect to database for CV embeddings (READ-ONLY)
        connection_string = os.getenv("DATABASE_URL")
        if connection_string:
            try:
                vectorstore = CustomPGVector(
                    connection_string=connection_string,
                    embedding_function=embeddings
                )
                logger.info("Connected to database for CV embeddings (READ-ONLY)")
            except Exception as db_error:
                logger.warning(f"Database connection failed, using fallback: {str(db_error)}")
                vectorstore = None
        
        # Fallback to in-memory if database unavailable
        if not vectorstore:
            from langchain_community.vectorstores import Chroma
            
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
            
            # Initialize vector store with Chroma (in-memory fallback)
            vectorstore = Chroma.from_documents(
                documents=split_docs,
                embedding=embeddings
            )
            logger.info("Using in-memory vector store (fallback)")
        
        logger.info("AI components initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize AI components: {str(e)}")
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
                search_kwargs={"k": 4}
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

@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint"""
    return {
        "message": "CV Chatbot API with LangChain",
        "version": "2.0.0",
        "docs": "/docs",
        "privacy": "This service processes messages with OpenAI API and accesses READ-ONLY CV data but does not store user chat history."
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
    """Main chat endpoint using LangChain"""
    try:
        # Generate session ID if not provided
        session_id = message.session_id or f"session_{datetime.utcnow().timestamp()}"
        
        # Get conversation chain for this session
        chain = get_conversation_chain(session_id)
        
        # Process the message using invoke
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
        
        # Log the interaction (console only, no database storage of user data)
        logger.info(
            f"Chat interaction - Session: {session_id}, Question length: {len(message.message)}, Response length: {len(result['answer'])}, Sources: {sources}"
        )
        
        return ChatResponse(
            response=result["answer"],
            session_id=session_id,
            sources=sources,
            conversation_id=session_id
        )
        
    except Exception as e:
        logger.error(f"Chat error - Session: {session_id}, Error: {str(e)}")
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
            logger.info(f"Session reset: {session_id}")
            return {"message": f"Session {session_id} reset successfully"}
        else:
            return {"message": f"Session {session_id} not found"}
    except Exception as e:
        logger.error(f"Session reset error - Session: {session_id}, Error: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to reset session")

@app.get("/active-sessions")
async def get_active_sessions():
    """Get list of active conversation sessions"""
    return {
        "active_sessions": list(conversation_chains.keys()),
        "count": len(conversation_chains)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        log_level="info",
        reload=True
    ) 