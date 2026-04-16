import * as z from "zod";
import { fetchResult, parseErrors, type ResultType, ResultSchema } from "../utils.ts";

// ----------------------------------------------------------------------------
// Schemas

// This type is used to define the shape of our data.
export const Schema = z.object({
    // accessionNumber: z.string(),
    // acquisitionDate: z.coerce.date(),
    // additionalInfo: z.object({
    //   additionalProps: z.record(z.string(), z.string()),
    // }).nullable(),
    // biologicalStatusOfAccessionCode: z.number(),
    // biologicalStatusOfAccessionDescription: z.string().nullable(),
    // breedingMethodDbId: z.string().nullable(),
    // collection: z.string().nullable(),
    // commonCropName: z.string(),
    // countryOfOriginCode: z.string(),
    // defaultDisplayName: z.string(),
    // documentationURL: z.string(),
    // // donors
    // // externalReferences
    // genus: z.string(),
    germplasmDbId: z.coerce.number().nullable().default(null),
    germplasmName: z.string().nullable().default(null),
    // // germplasmOrigin
    // germplasmPUI: z.string(),
    // germplasmPreprocessing: z.string().nullable(),
    // instituteCode: z.string(),
    // instituteName: z.string(),
    // pedigree: z.string(),
    // seedSource: z.string(),
    // seedSourceDescription: z.string(),
    species: z.string().nullable().default(null),
    // speciesAuthority: z.string().nullable(),
    // // storageTypes:
    // subtaxa: z.string().nullable(),
    // subtaxaAuthority: z.string().nullable(),
    // synonyms:
    // taxonIds
}).default({});
export type SchemaType = z.infer<typeof Schema>;

// Required schema to create a germplasm
export const CreateSchema = z.object({
    germplasmName: z.string({ error: (iss) => iss.input == null ? "Name is a required field." : `Name is invalid: ${iss.input}` }),
    species: z.string({ error: (iss) => iss.input == null ? "Species is a required field." : `Species is invalid: ${iss.input}` }),
});
export type CreateType = z.infer<typeof CreateSchema>;

// ----------------------------------------------------------------------------
// Actions

// Create new germplasm
export async function create({germplasm} : {germplasm: SchemaType}) {

  let result = ResultSchema.parse({});
  // Input validation
  let parsed = CreateSchema.safeParse(germplasm);
  result.error = parseErrors(parsed);
  if (result.error){ return result; }
  if (!parsed.data){
    result.error = "No germplasm data was given.";
    return result;
  }

  // Post data to backend server
  result = await fetchResult({
    url: `/germplasm`,
    method: 'POST',
    body: JSON.stringify([parsed.data]),
    errorMsg: 'Failed to create germplasm.',
    successMsg: 'Succeeded in creating germplasm.'
  });

  return result;
}


// Get germplasm
export async function get({params} : {params?: Object}): Promise<ResultType> {
    let url = `/germplasm`;
    if (params){
      let query = new URLSearchParams(params).toString();
      url += `?${query}`;
    }
    let result = await fetchResult({
        url: url,
        method: 'GET',
        errorMsg: 'Failed to fetch germplasm search.',
        successMsg: 'Succeeded in fetching germplasm search.'
    });

    if (result.data && result.data.result){
        result.data.result = result.data.result.data.map( (record) => Schema.parse( record ));
    }

    return result;
}

export async function detail({germplasmDbId, params} : {germplasmDbId: Number, params?: Object}): Promise<ResultType> {
    let url = `/germplasm/${germplasmDbId}`;
    if (params){
      let query = new URLSearchParams(params).toString();
      url += `?${query}`;
    }

    let result = await fetchResult({
        url: url,
        method: 'GET',
        errorMsg: 'Failed to fetch germplasm detail.',
        successMsg: 'Succeeded in fetching germplasm detail.'
    });

  if (result.data && result.data.result){
    result.data.result = Schema.parse(result.data.result);
  }

  return result;

}
