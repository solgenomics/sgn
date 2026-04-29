export function Page({children}) {
  return (
    <div className="w-full">
        <h1>Breeding Programs</h1>
        <hr className="mt-4 mb-8"/>
        <div className="inline-block w-11/12 mb-8">
            {children}
        </div>
    </div>
  )
}
