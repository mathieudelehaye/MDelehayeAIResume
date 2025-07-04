import 'package:flutter/material.dart';
import 'dart:async';
import 'widgets/chat_widget.dart';

void main() {
  runApp(const CVApp());
}

class CVApp extends StatelessWidget {
  const CVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mathieu Delehaye - CV',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();

    // Navigate to CV page after 4 seconds (giving people time to read)
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const CVPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.blue[700]!,
              Colors.blue[500]!,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Professional Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 60,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Name
                      Text(
                        'MATHIEU DELEHAYE',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'MSc Financial Mathematics',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Software Engineer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Contact Info
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'mathieu.delehaye@gmail.com',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'London, UK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Loading indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.7),
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CVPage extends StatelessWidget {
  const CVPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SelectionArea(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  margin: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 30),
                          _buildSummary(),
                          const SizedBox(height: 30),
                          _buildExperience(),
                          const SizedBox(height: 30),
                          _buildProjects(),
                          const SizedBox(height: 30),
                          _buildEducation(),
                          const SizedBox(height: 30),
                          _buildSkills(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const ChatWidget(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MATHIEU DELEHAYE',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'MSC FINANCIAL MATHEMATICS (PART-TIME)',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _buildContactInfo(Icons.location_on, 'London, UK'),
            _buildContactInfo(Icons.email, 'mathieu.delehaye@gmail.com'),
            _buildContactInfo(Icons.phone, '+44 7831 254 658'),
            _buildContactInfo(Icons.link, 'linkedin.com/in/mathieudelehaye'),
            _buildContactInfo(Icons.code, 'github.com/mathieudelehaye'),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PROFESSIONAL SUMMARY'),
        const SizedBox(height: 12),
        Text(
          'Software engineer with 10+ years of experience delivering robust, high-performance systems across cybersecurity, embedded, health tech, and finance. Currently pursuing a part-time MSc in Financial Mathematics at Queen Mary University of London to learn, gain exposure, and transition into the quantitative finance industry, with a strong focus on high-frequency trading (HFT) and asset management. Combining engineering rigour, real-time systems experience, and strong mathematical foundations. Eligible to work in the UK.',
          style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildExperience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PROFESSIONAL EXPERIENCE'),
        const SizedBox(height: 12),
        _buildExperienceItem(
          'Verimatrix',
          'Senior Software Engineer (Cybersecurity)',
          '2021 – 2024',
          'UK',
          [
            'Developed C/C++/Python protection tools with SQL for anti-tamper and obfuscation in client software (e.g., JPMorgan, Dolby)',
            'Reduced runtime overhead by 50% with a lightweight security mode',
            'Contributed to a client-facing React/Python Flask visualisation tool',
            'Implemented anti-debugging protections on Android/Linux by bypassing kernel-level restrictions',
            'Diagnosed low-level issues using gdb, pdb, Procmon, and Ghidra',
            'Refactored Jenkins pipelines to support parallel builds, reducing build times by 25%',
          ],
        ),
        const SizedBox(height: 20),
        _buildExperienceItem(
          'Metix Medical',
          'Software Engineer (Digital Health)',
          '2020 – 2021',
          'UK',
          [
            'Designed ECG digital filters in Python/Numpy/SciPy and implemented in embedded C for DSP',
            'Developed C++/Qt software on Yocto Linux, aligned with ISO 13485 and UX specs',
          ],
        ),
        const SizedBox(height: 20),
        _buildExperienceItem(
          'Alstom (via Abylsen)',
          'Software Engineering Consultant (Transportation)',
          '2019 – 2020',
          'Belgium',
          [
            'Developed real-time signalling software in C and PLC (CODESYS) to improve train driver awareness and reduce operational incidents',
            'Engineered automatic reconnection with the train\'s central computer and resolved TCP/CIP buffer overflow issues using Wireshark',
            'Increased system robustness and reusability with shared libraries; implemented secure driver authentication using a C-based SHA-1 hashing library',
          ],
        ),
        const SizedBox(height: 20),
        _buildExperienceItem(
          'Smals',
          'Project Manager (eGovernment, Finance)',
          '2013 - 2019',
          'Belgium',
          [
            'Developed Python/SQL tools for automating access to tax and income data',
            'Managed projects for finance and healthcare; maintained SOAP services',
            'Delivered citizen records to tax authorities and banks',
          ],
        ),
        const SizedBox(height: 20),
        _buildExperienceItem(
          'Alpha Technologies',
          'Embedded Software Engineer (Energy)',
          '2012 - 2013',
          'Belgium',
          [
            'Built embedded C#/.NET systems with CAN and TCP for power monitoring',
            'Designed load balancing algorithm that reduced energy loss by 15%',
          ],
        ),
      ],
    );
  }

  Widget _buildProjects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PROJECTS'),
        const SizedBox(height: 12),
        _buildProjectItem(
          'FintechModeler',
          '2023 – 2025',
          'github.com/mathieudelehaye/FintechModeler',
          'Python/Pandas/C++ app to price European options using Black–Scholes and binomial models; GUI and REST API deployed on Azure.',
        ),
      ],
    );
  }

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('EDUCATION'),
        const SizedBox(height: 12),
        _buildEducationItem(
          'MSc Financial Mathematics (part-time), expected First-Class',
          'Queen Mary University of London',
          '2024 - 2026',
          'Modules: Mathematical Modelling in Finance, Advanced Derivatives Pricing and Risk Management (hedging, diversification and mean-variance analysis, utility maximisation), Continuous-Time Models in Finance, Financial Markets and Instruments, Machine Learning with Python, Neural Networks and Deep Learning, C++ for Finance, Advanced Computing in Finance.',
        ),
        const SizedBox(height: 16),
        _buildEducationItem(
          'MEng Electrical Engineering & Master in Management, 2:1',
          'University of Mons',
          '',
          'Modules: Statistics, Signal Processing, Modern Physics, Electronic Systems, Computer Networks, Microeconomics. Finance project: Statistical analysis of quality regulation impact on company ROA/ROS in R. Electronic project: LCD scrolling message display using Xilinx Spartan FPGA and Verilog; debugged and optimised with logic analyser. Dissertation: Unsupervised ML for tumour detection in medical imaging using K-means and transforms (Fourier, Cosine, Wavelet).',
        ),
      ],
    );
  }

  Widget _buildSkills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SKILLS & CERTIFICATIONS'),
        const SizedBox(height: 12),
        _buildSkillCategory(
          'Languages',
          'English (C1), French (native), Dutch (intermediate)',
        ),
        const SizedBox(height: 8),
        _buildSkillCategory(
          'Technical Skills',
          'Python (5 years), NumPy, Pandas, SciPy, C++, Embedded C, C#, SQL, Bash, VBA/Excel, Bluetooth, TCP/IP, CAN bus, Linux, DSP, real-time systems, multithreading (pthreads, std::thread), gdb, pdb, Procmon, Ghidra, Jenkins, Docker, Git, Kubernetes, AWS (EC2, S3), Azure, REST APIs, React, scikit-learn, MATLAB, R, Bloomberg Terminal, statistical testing, mathematical modelling for finance, Agile/Scrum, CI/CD pipelines, communication, problem-solving',
        ),
        const SizedBox(height: 8),
        _buildSkillCategory('Certifications', 'Bloomberg BMC, ITIL Foundation'),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.blue[300]!, width: 2),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceItem(
    String company,
    String position,
    String period,
    String location,
    List<String> achievements,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$company | $position',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              '$period | $location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...achievements.map(
          (achievement) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(color: Colors.blue[600], fontSize: 16),
                ),
                Expanded(
                  child: Text(
                    achievement,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectItem(
    String name,
    String period,
    String link,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$period | $link',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: Colors.blue[600], fontSize: 16)),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEducationItem(
    String degree,
    String institution,
    String period,
    String details,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                degree,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            if (period.isNotEmpty)
              Text(
                period,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          institution,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          details,
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildSkillCategory(String category, String skills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$category:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          skills,
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey[800]),
        ),
      ],
    );
  }
}
