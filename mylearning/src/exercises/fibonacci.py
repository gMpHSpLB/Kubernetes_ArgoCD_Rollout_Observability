#Add docstrings
def fibonacci(n):
    """
    Compute nth Fibonacci number.

    Args:
        n (int): position

    Returns:
        int: fibonacci value
    """
    a, b = 0, 1
    result = []
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result


