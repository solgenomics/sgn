import { brapiUrl } from "./";
import { z } from 'zod';

// Generic return type for functions in this module
export const ResultSchema = z.object({
    error: z.string().nullable().default(null),
    success: z.string().nullable().default(null),
    data: z.object().nullable().default({}),
}).default({});
export type ResultType = z.infer<typeof ResultSchema>;

export async function fetchResult({ baseUrl, url, method, errorMsg, successMsg, body }: {baseUrl?: string, url: string, method: string, errorMsg: string, successMsg: string, body?: Object}) {

    let result = ResultSchema.parse({});
    if (baseUrl == null){
      baseUrl = brapiUrl;
    }

    let response: Response;
    try {
        response = await fetch(`${baseUrl}${url}`, {method: method, credentials: "include", body: body} );
    } catch(error) {
        result.error = error.message;
        return result;
    }

    if (!response.ok){
        result.error = `${errorMsg} ${response.statusText} (${response.status}).`
    } else {
        // Check if we have an error message
        result.data = await response.json();
        if (result.data.error) {
        result.error = `${errorMsg} ${result.data.error}`
        } else {
        result.success = `${successMsg}`;
        }
    }

  return result;
}

export function parseErrors(parsed) {
  if (!parsed.success) {
    let errorMessages: string[] = [];
    parsed.error.issues.forEach((issue) => {
      errorMessages.push(issue.message);
    })
    return errorMessages.join(" ");
  } else {
    return null;
  }
}
