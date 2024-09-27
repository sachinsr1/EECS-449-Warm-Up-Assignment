walker interact {
    can return_message with `root entry {
        report {
            "response": "Hello, world!"
        };
    }
}

walker interact_with_body {
    has name: str;

    can return_message with `root entry {
        report {
            "response": "Hello, " + self.name + "!"
        };
    }
}

walker double_number {
    has number1: int;

    can return_message with `root entry {
        let double = self.number1 * 2;
        report {
            "response": "The doubled value of " + self.number1 + " is " + double + "."
        };
    }
}

walker introduce_person {
    has name: str;
    has occupation: str;

    can return_message with `root entry {
        report {
            "response": "Hi, my name is " + self.name + " and I am a " + self.occupation + "."
        };
    }
}