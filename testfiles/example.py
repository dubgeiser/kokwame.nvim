def testing_separate_function() -> None:
    print("The owls are not what they seem")


class TestingWanToe:

    def __init__(self, name:str) -> None:
        self.name = name

    # Cyclomatic complexity: 12
    def get_name(self) -> str:
        a = [i for i in [j for j in range(0, 10)]]
        while True:
            print("hello")
            break

        if self.name ==  'string' or self == 'String':
            return self.name
        elif self.name == 'int' or self.name == 'float' and self.name != 'object' or self.name == 'fubar' and self.name != 'foobar':
            for i in range(1, 10):
                if i == 5:
                    print(4)
                elif i == 6:
                    print(2)
                else:
                    print('freedom')
            return self.name
        return self.name

    @staticmethod
    def create():
        return TestingWanToe('default')
