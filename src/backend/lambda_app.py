"""
Lambda handler for AWS Lambda deployment
Adapts Lambda event format to FastAPI request format
"""
import json
import logging
from typing import Dict, Any
from mangum import Mangum

from src.backend.fastapi_app import app

# Configure logging for Lambda
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create Mangum handler to adapt Lambda events to ASGI
handler = Mangum(app, lifespan="off")


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda entry point

    Args:
        event: Lambda event object (API Gateway proxy format)
        context: Lambda context object

    Returns:
        API Gateway proxy response format
    """
    # Log incoming request
    logger.info(f"Lambda invoked with event: {json.dumps(event, default=str)}")
    logger.info(f"Request ID: {context.request_id}")

    try:
        # Use Mangum to handle the request
        response = handler(event, context)

        logger.info(f"Response status: {response.get('statusCode', 'unknown')}")
        return response

    except Exception as e:
        logger.error(f"Lambda handler error: {str(e)}", exc_info=True)

        # Return error response in API Gateway format
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({
                "detail": "Internal server error"
            })
        }
