.PHONY: install run build clean

# 의존성 설치
install:
	pnpm install

# 서버 실행 — .env 의 설정을 읽어 NestJS 서버를 기동
run: install
	@if [ ! -f .env ]; then \
		echo "✗ .env 가 없습니다. 'cp .env.sample .env' 후 값을 채워주세요."; \
		exit 1; \
	fi
	pnpm start

# 프로덕션 빌드 (dist/main.js)
build: install
	pnpm run build

# 빌드 산출물 및 의존성 정리
clean:
	rm -rf dist node_modules
