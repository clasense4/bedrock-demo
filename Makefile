.PHONY: help build up down logs clean install test

help:
	@echo "Available commands:"
	@echo "  make build    - Build Docker containers"
	@echo "  make up       - Start the application"
	@echo "  make down     - Stop the application"
	@echo "  make logs     - View application logs"
	@echo "  make clean    - Remove containers and volumes"
	@echo "  make install  - Install Python dependencies locally"
	@echo "  make test     - Run backend tests"

build:
	docker-compose build

up:
	docker-compose up -d
	@echo "Application started!"
	@echo "Frontend: http://localhost:8080"
	@echo "Backend: http://localhost:8000"
	@echo "API Docs: http://localhost:8000/docs"

down:
	docker-compose down

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	docker system prune -f

install:
	pip install -r requirements.txt

test:
	pytest tests/ -v
