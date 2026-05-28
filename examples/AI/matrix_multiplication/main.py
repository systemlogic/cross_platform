import time
import torch
from concurrent.futures import ThreadPoolExecutor, as_completed


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

    tasks = {
        "cpu": (run_cpu, x, y),
        "mps": (run_mps, x, y),
    }

    results = {}
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {
            executor.submit(fn, *args): name
            for name, (fn, *args) in tasks.items()
        }
        for future in as_completed(futures):
            name = futures[future]
            elapsed, result = future.result()
            results[name] = (elapsed, result)
            print("task on device {} took = {:.4f} sec".format(result.device, elapsed))

    cpu_time = results["cpu"][0]
    mps_time = results["mps"][0]
    print("\ngpu is {:.1f}x faster than cpu".format(cpu_time / mps_time))


if __name__ == "__main__":
    main()
