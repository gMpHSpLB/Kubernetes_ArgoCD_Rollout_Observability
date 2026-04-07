from exercises.fibonacci import fibonacci


def test_fibonacci_basic() -> None:
    assert fibonacci(5) == [0, 1, 1, 2, 3]


def test_fibonacci_zero() -> None:
    assert fibonacci(0) == []
