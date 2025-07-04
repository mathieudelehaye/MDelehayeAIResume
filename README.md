# Mathieu Delehaye - Interactive CV

A modern, responsive CV built with Flutter that works on web, mobile, and desktop platforms.

## 🚀 Features

- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile
- **Modern UI**: Clean, professional layout with Material Design
- **SEO Optimized**: Includes proper meta tags and sitemap for search engines
- **Cross-Platform**: Single codebase for web, Android, iOS, and desktop
- **Interactive**: Smooth animations and professional styling

## 🛠️ Tech Stack

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **Material Design**: Google's design system
- **HTML**: SEO-friendly web deployment

## 📋 Prerequisites

Before running this project, make sure you have:

1. **Flutter SDK** installed ([Installation Guide](https://docs.flutter.dev/get-started/install))
2. **A code editor** (VS Code, Android Studio, or IntelliJ)
3. **Web browser** (Chrome, Firefox, Safari, or Edge)

## 🏃‍♂️ How to Run

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd cv_flutter_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run on Different Platforms

#### Web (Browser)
```bash
flutter run -d chrome
```

#### Mobile (with emulator/device connected)
```bash
flutter run
```

#### Desktop
```bash
flutter run -d windows  # or macos, linux
```

## 🌐 Building for Web Deployment

### 1. Build for Web (SEO-Friendly)

```bash
flutter build web --web-renderer=html
```

This creates a `build/web` folder with all the necessary files for web deployment.

### 2. Serve Locally (Testing)

```bash
# Using Python (if installed)
cd build/web
python -m http.server 8000

# Or using Node.js serve package
npm install -g serve
serve -s build/web -p 8000
```

Visit `http://localhost:8000` to view your CV website.

## 🔧 Deployment Options

### Option 1: Azure Container Apps (Recommended)

1. **Create a Dockerfile**:
```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

2. **Build and deploy**:
```bash
# Build the web app
flutter build web --web-renderer=html

# Build Docker image
docker build -t mathieu-cv .

# Deploy to Azure Container Apps
az containerapp create \
  --name mathieu-cv \
  --resource-group your-resource-group \
  --image mathieu-cv \
  --target-port 80 \
  --ingress external
```

### Option 2: GitHub Pages

1. **Create `.github/workflows/deploy.yml`**:
```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter build web --web-renderer=html
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

### Option 3: Netlify/Vercel

1. **Build the project**:
```bash
flutter build web --web-renderer=html
```

2. **Deploy the `build/web` folder** to Netlify or Vercel

## 📱 Building for Mobile

### Android APK
```bash
flutter build apk --release
```

### iOS (macOS required)
```bash
flutter build ios --release
```

## 🔍 SEO Configuration

The project includes SEO optimizations:

- **Meta tags** in `web/index.html`
- **Sitemap** at `web/sitemap.xml`
- **HTML renderer** for better crawling
- **Open Graph** tags for social sharing

### Google Search Console Setup

1. Go to [Google Search Console](https://search.google.com/search-console)
2. Add your website URL
3. Verify ownership using the HTML meta tag method
4. Submit your sitemap: `https://yourdomain.com/sitemap.xml`

## 📁 Project Structure

```
cv_flutter_app/
├── lib/
│   └── main.dart          # Main application code
├── web/
│   ├── index.html         # SEO-optimized HTML
│   └── sitemap.xml        # Search engine sitemap
├── pubspec.yaml           # Flutter dependencies
└── README.md             # This file
```

## 🎨 Customization

### Styling
- Colors and themes are defined in `lib/main.dart`
- Modify the `ThemeData` in the `CVApp` class
- Change colors in the `Colors.blue` references

### Content
- Update personal information in the `_buildHeader()` method
- Modify experience in the `_buildExperience()` method
- Add projects in the `_buildProjects()` method

### Layout
- The CV is responsive and uses a card-based design
- Maximum width is set to 800px for optimal readability
- All sections are modular and can be reordered

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 📧 Contact

**Mathieu Delehaye**
- Email: mathieu.delehaye@gmail.com
- LinkedIn: [linkedin.com/in/mathieudelehaye](https://linkedin.com/in/mathieudelehaye)
- GitHub: [github.com/mathieudelehaye](https://github.com/mathieudelehaye)

---

*Built with ❤️ using Flutter*
