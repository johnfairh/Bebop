#
TEST_COMMAND=swift test --parallel

all:

test:
	${TEST_COMMAND}

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name j2 --rm swift:5.1 ${TEST_COMMAND} --enable-test-discovery
