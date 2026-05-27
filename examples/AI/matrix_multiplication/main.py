import time
import torch


def run_cpu(x: torch.Tensor, y: torch.Tensor) -> tuple[float, torch.Tensor]:
    start = time.time()
    result = torch.matmul(x, y)
    return time.time() - start, result


def run_mps(x: torch.Tensor, y: torch.Tensor) -> tuple[float, torch.Tensor]:
    device = torch.device("mps")
    x_gpu = x.to(device)
    y_gpu = y.to(device)
    start = time.time()
    result = torch.matmul(x_gpu, y_gpu)
    torch.mps.synchronize()
    return time.time() - start, result


def main() -> None:
    if not torch.backends.mps.is_available():
        print("MPS not available — this benchmark requires Apple Silicon with MPS support.")
        return

    matrix_size = 64 * 256
    x = torch.randn(matrix_size, matrix_size)
    y = torch.randn(matrix_size, matrix_size)

    print("============= CPU SPEED ===========")
    cpu_time, cpu_result = run_cpu(x, y)
    print("task on device {} took = {:.4f} sec".format(cpu_result.device, cpu_time))

    print("============= MPS (GPU) SPEED ===========")
    mps_time, mps_result = run_mps(x, y)
    print("task on device {} took = {:.4f} sec".format(mps_result.device, mps_time))

    print("\ngpu is {:.1f}x faster than cpu".format(cpu_time / mps_time))


if __name__ == "__main__":
    main()
