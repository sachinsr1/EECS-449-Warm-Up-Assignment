import:py from mtllm.llms {Ollama}

glob llm = Ollama(model_name='llama3.1');

import:jac from rag {RagEngine}
glob rag_engine:RagEngine = RagEngine();

enum ChatType {
    RAG : "RAG",
    QA : "user_qa",
    INFO : "INFO_REQUEST"
}

node Router {
    can classify(message: str) -> ChatType {
        print(f"Classifying message: {message}");
        if ("tell me more") in message.lower() or ("elaborate") in message.lower() or ("explain") in message.lower() {
            print("Classification: INFO_REQUEST");
            return ChatType.INFO;
        }
        print("Classification: RAG");
        return ChatType.RAG;
    }
}

walker interact {
    has message: str;
    has session_id: str;

    can init_session with `root entry {
         visit [-->](`?Session)(?id == self.session_id) else {
            session_node = here ++> Session(id=self.session_id, chat_history=[], status=1);
            print("Session Node Created");
            visit session_node;
        }
    }
}

node Session {
    has id: str;
    has chat_history: list[dict];
    has status: int = 1;

    can llm_chat(
        message: 'current message': str,
        chat_history: 'chat history': list[dict],
        agent_role: 'role of the agent responding': str,
        context: 'retrieved context from documents': list
    ) -> 'response': str by llm();

    can chat with interact entry {
        print(f"User message received: {here.message}");
        self.chat_history.append({"role": "user", "content": here.message});
        
        response = infer(message=here.message, chat_history=self.chat_history) spawn root;
        self.chat_history.append({"role": "assistant", "content": response.response});
        
        print(f"Assistant response: {response.response}");

        report {
            "response": response.response
        };
    }
}

walker infer {
    has message: str;
    has chat_history: list[dict];

    can init_router with `root entry {
        print("Initializing router...");
        visit [-->](`?Router) else {
            router_node = here ++> Router();
            router_node ++> RagChat();
            router_node ++> QAChat();
            router_node ++> InfoRequestChat();
            print("Router node created and visiting.");
            visit router_node;
        }
    }

    can route with Router entry {
        print("Routing message...");
        classification = here.classify(message = self.message);
        print(f"Classification result: {classification}");
        
        if classification == ChatType.INFO {
            print("Visiting InfoRequestChat node...");
            visit [-->](`?InfoRequestChat);
        } else {
            print("Visiting Chat node for classification...");
            visit [-->](`?Chat)(?chat_type == classification);
        }
    }
}

node Chat {
    has chat_type: ChatType;
}

node InfoRequestChat :Chat: {
    has chat_type: ChatType = ChatType.INFO;

    can respond with infer entry {
        print(f"Responding in InfoRequestChat for message: {here.message}");
        can respond_with_llm(message: 'current message': str,
                             chat_history: 'chat history': list[dict],
                             agent_role: 'role of the agent responding': str
                            ) -> 'response': str by llm();
        here.response = respond_with_llm(here.message, here.chat_history, 
                                          agent_role="You are a conversation agent designed to enhance a user's knowledge even more on a subject");
        print(f"INFO_REQUEST response generated: {here.response}");
    }
}

node RagChat :Chat: {
    has chat_type: ChatType = ChatType.RAG;

    can respond with infer entry {
        print(f"Responding in RagChat for message: {here.message}");
        can respond_with_llm(message: 'current message': str,
                             chat_history: 'chat history': list[dict],
                             agent_role: 'role of the agent responding': str,
                             context: 'retrieved context from documents': list
                            ) -> 'response': str by llm();
        
        data = rag_engine.get_from_chroma(query=here.message);
        print(f"Data retrieved from RagEngine: {data}");
        
        here.response = respond_with_llm(here.message, here.chat_history, 
                                          "You are a conversation agent designed to help users with their queries based on the documents provided", 
                                          data);
        print(f"RAG response generated: {here.response}");
    }
}

node QAChat :Chat: {
    has chat_type: ChatType = ChatType.QA;

    can respond with infer entry {
        print(f"Responding in QAChat for message: {here.message}");
        can respond_with_llm(message: 'current message': str,
                             chat_history: 'chat history': list[dict],
                             agent_role: 'role of the agent responding': str
                            ) -> 'response': str by llm();
        
        here.response = respond_with_llm(here.message, here.chat_history, 
                                          agent_role="You are a conversation agent designed to help users with their queries");
        print(f"QA response generated: {here.response}");
    }
}
