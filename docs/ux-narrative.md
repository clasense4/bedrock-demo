# AWS Bedrock Demo - UI

“A user types a message, the frontend sends it to the backend, the backend asks the Strands agent (powered by Bedrock) for the answer, and the frontend displays the reply—simple, fast, frictionless.”

## 0. Prerequisites

- AWS Region is us-east-1, this is to avoid using paid Cohore model
    - AWS Titan model will be used
- AWS Bedrock Knowledge Base is already setup correctly
    - Data Source is Web Crawler and already setup correctly (i.e https://axrail.ai)
    - Knowledge Base has been sync
- Frontend
    - HTML + Vanilla Javascript
- Backend
    - FastAPI + Strands Agent
- Local Environment
    - Docker + Docker Compose
- Prod Environment
    - Frontend: Cloudfront + S3
    - Backend: API Gateway + Lambda

## 1. User arrives on the website

- The user opens the chat page at https://yourdomain.com.
- The page loads instantly because it’s served via CloudFront + S3.

## 2. User sees a clean, minimal chat interface

- A message log area (empty at first).
- A header showing Knowledge Base Data Source (i.e https://axrail.ai)
- A text input at the bottom (“Type your question…”).
- A single “Send” button.

## 3. User starts the conversation

- The user types a message (e.g., List Axrail services”).
- When they click “Send”:
  - Their message appears in the chat log instantly (optimistic UI).
  - A small “Thinking…” indicator shows the system is working.
- The browser sends a POST request to /api/chat.

## 4. Frontend talks to the backend

- The browser sends a POST request to /api/chat.
- This goes through CloudFront → API Gateway → Lambda.
- Lambda hosts the FastAPI backend and passes the message to the Strands agent.

## 5. Agent generates a response

- The Strands agent processes the user’s message using Bedrock.
- The agent returns the reply text to the FastAPI endpoint.
- FastAPI returns:
  { "reply": "Here’s Axrail services ..." }

## 6. Backend sends the response to the frontend

- FastAPI sends the response back to the browser.
- The browser receives the response and updates the chat log.

## 7. User continues the conversation

- The user types another message.
- The browser sends another POST request to /api/chat.
- The process repeats.

## 8. Error handling

- If the API call fails (network / AWS / timeout):
  - The UI shows a friendly message like:
    “Oops — the server had a hiccup. Try again!”
  - User can retry without losing previous messages.

## 9. End of session

- The user simply closes the page.
- No login is required (unless you add auth later).
- The chat log persisted locally in the user's browser.
