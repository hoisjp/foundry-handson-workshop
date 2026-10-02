"""Lab 3-1: Call a deployed model through the Foundry project (Responses API)."""
import os

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

# Format: https://<resource-name>.services.ai.azure.com/api/projects/<project-name>
PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
MODEL_DEPLOYMENT = os.environ.get("MODEL_DEPLOYMENT", "gpt-5.4-mini")

project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
openai = project.get_openai_client()

response = openai.responses.create(
    model=MODEL_DEPLOYMENT,
    input="Explain Microsoft Foundry in two sentences for a first-time user. Answer in Japanese.",
)
print(response.output_text)
