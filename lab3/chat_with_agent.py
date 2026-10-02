"""Lab 3-2: Chat with the agent you built in the portal (Lab 2), with multi-turn conversation."""
import os

from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

# Format: https://<resource-name>.services.ai.azure.com/api/projects/<project-name>
PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
AGENT_NAME = os.environ["AGENT_NAME"]

project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
openai = project.get_openai_client()

# A conversation keeps the chat history on the service side.
conversation = openai.conversations.create()
print(f"Connected to agent '{AGENT_NAME}'. Type 'exit' to quit.")

while True:
    question = input("\nYou> ").strip()
    if not question:
        continue
    if question.lower() in {"exit", "quit"}:
        break

    response = openai.responses.create(
        conversation=conversation.id,
        input=question,
        extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
    )
    print(f"\nAgent> {response.output_text}")
