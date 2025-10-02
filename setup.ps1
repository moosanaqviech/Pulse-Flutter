# Create Flutter project
flutter create pulse_flutter
cd pulse_flutter

# Create directory structure
New-Item -ItemType Directory -Force -Path "lib/models"
New-Item -ItemType Directory -Force -Path "lib/services" 
New-Item -ItemType Directory -Force -Path "lib/screens"
New-Item -ItemType Directory -Force -Path "lib/widgets"
New-Item -ItemType Directory -Force -Path "lib/utils"

# Remove default files
Remove-Item "lib/main.dart"
Remove-Item "test/widget_test.dart"

Write-Host "Project structure created! Now copy the code from the artifacts."