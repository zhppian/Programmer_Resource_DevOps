# --- Build React Frontend ---
FROM node:20 as frontend
WORKDIR /app/frontend
COPY frontend/package*.json ./  
RUN npm install
COPY frontend/ ./               
RUN npm run build                

# --- Build Python Backend ---
FROM python:3.13-slim as backend
WORKDIR /app
COPY backend/ /app/backend/             
COPY --from=frontend /app/frontend/build /app/backend/static/  
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --- Run Backend with Frontend Static Files ---
CMD ["python", "backend/app.py"]
        