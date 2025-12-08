import json, numpy as np

def rel_err(a,b):
    num = np.linalg.norm(a-b)
    den = np.linalg.norm(b) + 1e-30
    return num/den, np.max(np.abs(a-b))

# пример сравнения c numpy.fft
N=1024
x = np.exp(2j*np.pi*7*np.arange(N)/N)
ref = np.fft.fft(x)
# сюда подставьте вывод вашей программы (сериализуйте как бинарник или текст)
# cur = ...
# print(rel_err(cur, ref))