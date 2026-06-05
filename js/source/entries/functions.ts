export function debounce(fn: Function, delay: number) {
    let timer: ReturnType<typeof setTimeout>;
    return function(...args: any[]) {
        clearTimeout(timer);
        timer = setTimeout(() => fn.apply(this, args), delay);
    };
}