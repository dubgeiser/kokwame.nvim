
class TestingWanToe:

    def __init__(self, name:str) -> None:
        self.name = name

    def get_name(self) -> str:
        if self.name ==  'string' or self == 'String':
            return self.name
        elif self.name == 'int' or self.name == 'float' and self.name != 'object':
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
