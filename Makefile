.PHONY: build install dmg clean

APP_NAME = Xowcase
RELEASE_DIR = build/macos/Build/Products/Release

help:
	@echo "Comandos disponíveis:"
	@echo "  make build   - Compila o aplicativo em modo Release"
	@echo "  make install - Compila e instala o app direto na sua pasta de Aplicativos"
	@echo "  make dmg     - Compila e cria um instalador .dmg profissional"
	@echo "  make clean   - Limpa os arquivos de build do Flutter"

build:
	@echo "🔨 Construindo $(APP_NAME) para macOS (Release)..."
	flutter build macos --release

install: build
	@echo "🚀 Instalando $(APP_NAME) na sua pasta Applications..."
	@rm -rf "/Applications/$(APP_NAME).app" || rm -rf "~/Applications/$(APP_NAME).app"
	@cp -R $(RELEASE_DIR)/*.app "/Applications/$(APP_NAME).app" 2>/dev/null || cp -R $(RELEASE_DIR)/*.app "~/Applications/$(APP_NAME).app"
	@echo "✅ Instalação concluída! Você já pode abrir o $(APP_NAME) pelo Launchpad ou Spotlight."

dmg: build
	@echo "📦 Criando imagem DMG do $(APP_NAME)..."
	@mkdir -p build/dmg_stage
	@rm -rf build/dmg_stage/*
	@cp -R $(RELEASE_DIR)/*.app build/dmg_stage/
	@ln -s /Applications build/dmg_stage/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder build/dmg_stage -ov -format UDZO build/$(APP_NAME).dmg
	@rm -rf build/dmg_stage
	@echo "✅ Arquivo DMG gerado com sucesso em: build/$(APP_NAME).dmg"
	@open build/

clean:
	@echo "🧹 Limpando cache e arquivos de build..."
	flutter clean
