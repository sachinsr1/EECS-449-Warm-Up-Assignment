import:py from transformers {pipeline}
import:jac from rag {RagEngine}

glob llm_gpt2 = pipeline("text-generation", model="gpt2");
glob rag_engine:RagEngine = RagEngine();

node Session {
    has id: str;
    has chat_history: list[dict];
    has status: int = 1;

    can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
    llm_chat(
        message:'current message':str,
        chat_history: 'chat history':list[dict],
        agent_role:'role of the agent responding':str,
        context:'retrieved context from documents':list
    ) -> 'response':str by llm_gpt2();
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

    can chat with Session entry {
        here.chat_history.append({"role": "user", "content": self.message});
        data = rag_engine.get_from_chroma(query=self.message);
        
        response = llm_gpt2(self.message, max_length=50, num_return_sequences=1)[0]['generated_text'];

        here.chat_history.append({"role": "assistant", "content": response});
        report {"response": response};
    }

    can set_model_gpt2 with `root entry {
        print("Using GPT-2 model.");
    }
}
