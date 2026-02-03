import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";
import { CLINIC_CONFIG, DOCTORS } from "./config.mjs";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  // Detect event source: Lex fulfillment vs Connect direct invocation
  const isLexEvent = event.sessionState !== undefined;

  if (isLexEvent) {
    return handleLexEvent(event);
  } else {
    return handleConnectEvent(event);
  }
};

// Handle Lex V2 fulfillment events
async function handleLexEvent(event) {
  const inputTranscript = event.inputTranscript || "";
  const sessionAttributes = event.sessionState?.sessionAttributes || {};

  // Get conversation history from session attributes
  let conversationHistory = sessionAttributes.conversationHistory
    ? JSON.parse(sessionAttributes.conversationHistory)
    : [];

  let responseText = "";
  let endCall = false;

  try {
    // Handle empty input
    if (!inputTranscript || inputTranscript.trim() === "") {
      if (conversationHistory.length > 0) {
        responseText = "I'm sorry, I didn't quite catch that. Could you please repeat?";
      } else {
        responseText = CLINIC_CONFIG.greeting;
        conversationHistory = [{ role: "assistant", content: responseText }];
      }
    } else {
      // Check if user wants to end the call
      const lowerText = inputTranscript.toLowerCase();
      if (lowerText.includes("bye") ||
        lowerText.includes("goodbye") ||
        lowerText.includes("that's all") ||
        (lowerText.includes("thank you") && lowerText.includes("nothing"))) {
        responseText = "Thank you for calling Melbourne Medical Clinic. Have a wonderful day! Goodbye.";
        endCall = true;
      } else {
        // Add user message to history
        conversationHistory.push({ role: "user", content: inputTranscript });

        // Get conversational response from LLM
        responseText = await getConversationalResponse(conversationHistory);

        // Add assistant response to history
        conversationHistory.push({ role: "assistant", content: responseText });

        // Keep history manageable
        if (conversationHistory.length > 20) {
          conversationHistory = conversationHistory.slice(-20);
        }
      }
    }
  } catch (error) {
    console.error("Error in Lex conversation:", error);
    responseText = "I'm sorry, I'm having trouble understanding. Could you please repeat that?";
  }

  // Return Lex V2 response format (no messages - Connect handles TTS)
  const lexResponse = {
    sessionState: {
      dialogAction: {
        type: "Close"
      },
      intent: {
        name: event.sessionState?.intent?.name || "VoiceCommand",
        state: "Fulfilled"
      },
      sessionAttributes: {
        responseText: responseText,
        conversationHistory: JSON.stringify(conversationHistory),
        endCall: endCall.toString()
      }
    }
  };

  console.log("Lex Response:", JSON.stringify(lexResponse));
  return lexResponse;
}

// Handle Connect direct invocation events
async function handleConnectEvent(event) {
  // Extract data from Connect event
  const contactData = event.Details?.ContactData || {};
  const attributes = contactData.Attributes || {};
  const parameters = event.Details?.Parameters || {};

  // Get user input and conversation history
  const userText = parameters.inputText || event.inputText || "";
  let conversationHistory = attributes.conversationHistory
    ? JSON.parse(attributes.conversationHistory)
    : [];

  let responseText = "";
  let endCall = false;

  try {
    // Special handling for initial "START" signal from Connect
    if (userText === "START") {
      responseText = CLINIC_CONFIG.greeting;
      conversationHistory = [{ role: "assistant", content: responseText }];
    }
    // Handle empty/missing input
    else if (!userText || userText.trim() === "") {
      if (conversationHistory.length > 0) {
        responseText = "I'm sorry, I didn't quite catch that. Could you please repeat?";
      } else {
        responseText = CLINIC_CONFIG.greeting;
      }
    } else {
      // Check if user wants to end the call
      const lowerText = userText.toLowerCase();
      if (lowerText.includes("bye") ||
        lowerText.includes("goodbye") ||
        lowerText.includes("that's all") ||
        lowerText.includes("thank you") && lowerText.includes("nothing")) {
        responseText = "Thank you for calling Melbourne Medical Clinic. Have a wonderful day! Goodbye.";
        endCall = true;
      } else {
        // Add user message to history
        conversationHistory.push({ role: "user", content: userText });

        // Get conversational response from LLM
        responseText = await getConversationalResponse(conversationHistory);

        // Add assistant response to history
        conversationHistory.push({ role: "assistant", content: responseText });

        // Keep history manageable
        if (conversationHistory.length > 20) {
          conversationHistory = conversationHistory.slice(-20);
        }
      }
    }
  } catch (error) {
    console.error("Error in Connect conversation:", error);
    responseText = "I'm sorry, I'm having trouble understanding. Could you please repeat that?";
  }

  // Return Connect response format
  const response = {
    responseText,
    conversationHistory: JSON.stringify(conversationHistory),
    endCall: endCall.toString()
  };
  console.log("Connect Response:", JSON.stringify(response));
  return response;
}

// Main conversational response function
async function getConversationalResponse(history) {
  const systemPrompt = `You are a friendly and professional receptionist at Melbourne Medical Clinic. 

CLINIC INFORMATION:
- Name: Melbourne Medical Clinic
- Address: 123 Collins Street, Melbourne VIC 3000
- Hours: Monday to Friday, 9:00 AM to 5:00 PM
- Phone: (03) 9000-1234

DOCTORS AVAILABLE:
1. Dr. Kasun Perera - General Practitioner, experienced GP for general consultations
2. Dr. Nimal Jayasinghe - General Practitioner, over 15 years of experience  
3. Dr. Sachini Fernando - General Practitioner, our female GP great with patients of all ages

YOUR ROLE:
- Answer questions about the clinic
- Help patients book appointments
- Be warm, friendly, and professional
- Keep responses concise (1-3 sentences)
- If someone wants to book an appointment, ask for: their preferred day, preferred time, and which doctor
- When booking is complete, confirm the details and say you'll send a reminder

IMPORTANT:
- You cannot actually book appointments in the system, but confirm you've "noted their booking"
- Do not end the conversation unless the caller says goodbye
- Always be helpful and ask if there's anything else you can help with`;

  const messages = history.map(msg => ({
    role: msg.role,
    content: msg.content
  }));

  const prompt = {
    anthropic_version: "bedrock-2023-05-31",
    max_tokens: 200,
    system: systemPrompt,
    messages: messages
  };

  console.log("Calling LLM with messages:", messages.length);

  const input = {
    modelId: "us.anthropic.claude-3-5-haiku-20241022-v1:0",
    contentType: "application/json",
    accept: "application/json",
    body: JSON.stringify(prompt)
  };

  try {
    const command = new InvokeModelCommand(input);
    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    console.log("LLM Response:", responseBody);

    return responseBody.content[0].text;
  } catch (error) {
    console.error("LLM Error:", error.name, error.message);
    throw error;
  }
}
