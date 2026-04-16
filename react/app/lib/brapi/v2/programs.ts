import { fetchResult, parseErrors, ResultSchema, type ResultType } from '../utils';
import * as z from "zod";

const publicBreedbaseUrl = import.meta.env.VITE_publicBreedbaseUrl;

// ----------------------------------------------------------------------------
// Schemas

// Default Breeding Program schema
export const Schema = z.object({
    abbreviation: z.string().nullable().default(null),
    additionalInfo: z.object({
        description: z.string().nullable().default(null),
    }).optional(),
    objective: z.string().nullable().default(null),
    programDbId:  z.string().default(null),
    programName:  z.string().default(null),
}).default({});
export type SchemaType = z.infer<typeof Schema>;


// Required schema to create a breeding program
export const CreateSchema = z.object({
    programName: z.string({ error: (iss) => iss.input == null ? "programName is a required field." : `programName is invalid: ${iss.input}` }),
    objective: z.string({ error: (iss) => iss.input == null ? "objective is a required field." : `objective is invalid: ${iss.input}` }),
    externalReferences: z.array(z.string()).nullable().default([])
});
export type CreateType = z.infer<typeof CreateSchema>;


// Required schema to edit a breeding program
export const EditSchema = z.object({
    programDbId: z.coerce.number({ error: (iss) => iss.input == null ? "programDbId is a required field." : `programDbId is invalid: ${iss.input}` }).int(),
    programName: z.string({ error: (iss) => iss.input == null ? "programName is a required field." : `programName is invalid: ${iss.input}` }),
    objective: z.string({ error: (iss) => iss.input == null ? "objective is a required field." : `objective is invalid: ${iss.input}` }),
});
export type EditType = z.infer<typeof EditSchema>;

// Required schema to remove a breeding program
export const RemoveSchema = z.object({
    programDbId: z.coerce.number({ error: (iss) => iss.input == null ? "programDbId is a required field." : `programDbId is invalid: ${iss.input}` }).int(),
});
export type RemoveType = z.infer<typeof RemoveSchema>;

// ----------------------------------------------------------------------------
// Actions

// Get breeding program(s)
export async function get({params} : {params?: Object}): Promise<ResultType> {
    let url = `/programs`;
    if (params){
      let query = new URLSearchParams(params).toString();
      url += `?${query}`;
    }
    let result = await fetchResult({
        url: url,
        method: 'GET',
        errorMsg: 'Failed to fetch programs search.',
        successMsg: 'Succeeded in fetching programs search.'
    });

    if (result.data && result.data.result){
        result.data.result = result.data.result.data.map( (record) => Schema.parse( record ));
    }

    return result;
}


// Create new breeding program
export async function create({program} : {program: SchemaType}) {

  let result = ResultSchema.parse({});
  // Input validation
  let parsed = CreateSchema.safeParse(program);
  result.error = parseErrors(parsed);
  if (result.error){ return result; }
  if (!parsed.data){
    result.error = "No breeding program data was given.";
    return result;
  }

  // Post data to backend server
  result = await fetchResult({
    url: `/programs`,
    method: 'POST',
    body: JSON.stringify([parsed.data]),
    errorMsg: 'Failed to create breeding program.',
    successMsg: 'Succeeded in creating breeding program.'
  });

  return result;
}


// Edit a breeding program details
export async function edit({program} : {program: SchemaType}) {
  let result = ResultSchema.parse({});

  // Input validation
  let parsed = EditSchema.safeParse(program);
  result.error = parseErrors(parsed);
  if (result.error){ return result; }
  if (!parsed.data){
    result.error = "No breeding program data was given.";
    return result;
  }

  // Post data to backend server
  result = await fetchResult({
    url: `/programs/${parsed.data.programDbId}`,
    method: 'PUT',
    body: JSON.stringify(parsed.data),
    errorMsg: 'Failed to edit breeding program.',
    successMsg: 'Succeeded in editing breeding program.'
  });

  return result;
}


// Remove a breeding program
export async function remove({program} : {program: SchemaType}) {
  let result = ResultSchema.parse({});

  // Input validation
  let parsed = RemoveSchema.safeParse(program);
  result.error = parseErrors(parsed);
  if (result.error){ return result; }
  if (!parsed.data){
    result.error = "No breeding program data was given.";
    return result;
  }

  // Post data to backend server
  result = await fetchResult({
    baseUrl: publicBreedbaseUrl,
    url: `/breeders/program/delete/${parsed.data.programDbId}`,
    method: 'POST',
    errorMsg: 'Failed to remove breeding program.',
    successMsg: 'Succeeded in removing breeding program.'
  });

  return result;
}
