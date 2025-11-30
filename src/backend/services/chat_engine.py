"""
ChatEngine service for integrating with AWS Bedrock via Strands Agent
"""
import os
import logging
from typing import Optional

from strands import Agent, tool
import boto3

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ChatEngine:
    """
    Service class for processing chat messages using AWS Bedrock Knowledge Base
    via Strands Agent framework
    """

    def __init__(
        self,
        knowledge_base_id: Optional[str] = None,
        region: Optional[str] = None,
        model_id: Optional[str] = None
    ):
        """
        Initialize ChatEngine with AWS Bedrock configuration

        Args:
            knowledge_base_id: AWS Bedrock Knowledge Base ID (defaults to env var)
            region: AWS region (defaults to env var)
            model_id: Bedrock model ID (defaults to env var)
        """
        self.knowledge_base_id = knowledge_base_id or os.getenv("KNOWLEDGE_BASE_ID")
        self.region = region or os.getenv("AWS_REGION", "us-east-1")
        self.model_id = model_id or os.getenv(
            "BEDROCK_MODEL_ID",
            "nova-micro-v1:0"
        )

        if not self.knowledge_base_id:
            raise ValueError("KNOWLEDGE_BASE_ID must be provided or set in environment")

        logger.info(
            f"Initializing ChatEngine with KB: {self.knowledge_base_id}, "
            f"Region: {self.region}, Model: {self.model_id}"
        )

        self.agent = self._create_agent()

    def _create_memory_tool(self):
        """Create a memory tool configured with the knowledge base"""
        kb_id = self.knowledge_base_id
        region = self.region
        
        @tool
        def memory(query: str, min_score: float = 0.4, max_results: int = 9) -> str:
            """Search the knowledge base for relevant information.
            
            Args:
                query: The search query
                min_score: Minimum relevance score (0-1)
                max_results: Maximum number of results to return
            """
            try:
                client = boto3.client('bedrock-agent-runtime', region_name=region)
                response = client.retrieve(
                    knowledgeBaseId=kb_id,
                    retrievalQuery={'text': query},
                    retrievalConfiguration={
                        'vectorSearchConfiguration': {
                            'numberOfResults': max_results
                        }
                    }
                )
                
                results = []
                for item in response.get('retrievalResults', []):
                    score = item.get('score', 0)
                    if score >= min_score:
                        content = item.get('content', {}).get('text', '')
                        results.append(f"[Score: {score:.2f}] {content}")
                
                if not results:
                    return "No relevant information found in the knowledge base."
                
                return "\n\n".join(results)
                
            except Exception as e:
                logger.error(f"Memory tool error: {str(e)}")
                return f"Error retrieving information: {str(e)}"
        
        return memory

    def _create_agent(self) -> Agent:
        """
        Create and configure Strands Agent with AWS Bedrock settings

        Returns:
            Configured Agent instance
        """
        try:
            # Create custom memory tool with KB configuration
            memory_tool = self._create_memory_tool()
            
            # Create agent with memory tool
            agent = Agent(
                tools=[memory_tool],
                model=self.model_id,
                system_prompt=(
                    "You are a helpful assistant that answers questions based on "
                    "the knowledge base. Use the memory tool to retrieve relevant "
                    "information before answering. When retrieving information, "
                    "use min_score=0.4 and max_results=9 for best results."
                )
            )

            logger.info("Agent created successfully")
            return agent

        except Exception as e:
            logger.error(f"Failed to create agent: {str(e)}")
            raise

    def process_message(self, message: str) -> str:
        """
        Process a user message and return the agent's response

        Args:
            message: User's input message

        Returns:
            Agent's reply text

        Raises:
            Exception: If agent fails to generate response
        """
        try:
            logger.info(f"Processing message: {message[:50]}...")

            # Send message to agent
            response = self.agent(message)

            # Extract reply text from response
            reply = self._extract_reply(response)

            logger.info(f"Generated reply: {reply[:50]}...")
            return reply

        except Exception as e:
            logger.error(f"Error processing message: {str(e)}")
            raise self._handle_agent_error(e)

    def _extract_reply(self, response) -> str:
        """
        Extract reply text from agent response

        Args:
            response: Agent response object

        Returns:
            Reply text as string
        """
        # Handle different response formats from Strands Agent
        if isinstance(response, str):
            return response
        elif hasattr(response, 'content'):
            return response.content
        elif hasattr(response, 'text'):
            return response.text
        elif isinstance(response, dict) and 'content' in response:
            return response['content']
        else:
            # Fallback: convert to string
            return str(response)

    def _handle_agent_error(self, error: Exception) -> Exception:
        """
        Process and wrap agent errors with appropriate error messages

        Args:
            error: Original exception

        Returns:
            Processed exception with user-friendly message
        """
        error_message = str(error)

        # Log the full error for debugging
        logger.error(f"Agent error details: {error_message}", exc_info=True)

        # Return a generic error to avoid exposing internal details
        return Exception("Failed to generate response from agent")
