#!/bin/bash
# fix_flutter_linker.sh - Исправление ошибки линковки Flutter-lc++

echo "🔧 Исправление ошибки линковки Flutter-lc++..."
echo ""

# Проверка что мы в правильной директории
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Ошибка: файл pubspec.yaml не найден"
    echo "Убедитесь что вы находитесь в корне проекта"
    exit 1
fi

# 1. Обновление Podfile с правильной линковкой
echo "1️⃣ Обновление ios/Podfile..."

cat > ios/Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      # Исправление iOS Deployment Target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # КРИТИЧНО: Исправление линковки C++
      config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
      
      # Удаляем все упоминания -lc++ и добавляем правильно один раз
      config.build_settings['OTHER_LDFLAGS'] = config.build_settings['OTHER_LDFLAGS'].map { |flag|
        flag == '-lc++' ? nil : flag
      }.compact
      
      # Добавляем -lc++ один раз
      config.build_settings['OTHER_LDFLAGS'] << '-lc++' unless config.build_settings['OTHER_LDFLAGS'].include?('-lc++')
      
      # Дополнительные настройки
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      
      # Убираем дублирование фреймворков
      config.build_settings['OTHER_CFLAGS'] ||= ['$(inherited)']
    end
  end
end
EOF

echo "✓ Podfile обновлен"

# 2. Полная очистка
echo ""
echo "2️⃣ Полная очистка проекта..."

flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData
cd ios
rm -rf Pods Podfile.lock .symlinks
rm -rf build
pod deintegrate 2>/dev/null || true
cd ..

echo "✓ Очистка завершена"

# 3. Получение зависимостей Flutter
echo ""
echo "3️⃣ Получение зависимостей Flutter..."
flutter pub get

# 4. Переустановка pods
echo ""
echo "4️⃣ Переустановка pods..."
cd ios
arch -arm64 pod install --repo-update

if [ $? -eq 0 ]; then
    echo "✓ Pods установлены успешно"
else
    echo "⚠️  Ошибка установки pods"
    cd ..
    exit 1
fi

cd ..

# 5. Проверка в Xcode (опционально)
echo ""
echo "5️⃣ Опционально: Проверьте настройки в Xcode..."
echo ""
echo "Если проблема сохраняется, откройте ios/Runner.xcworkspace в Xcode"
echo "и проверьте: Runner → Build Settings → Other Linker Flags"
echo "Должно быть: -lc++ (без дублирования)"

echo ""
echo "✅ Исправление завершено!"
echo ""
echo "📱 Попробуйте запустить:"
echo "   flutter run"
echo ""
echo "Если ошибка сохраняется, попробуйте:"
echo "   flutter run --verbose"
echo ""