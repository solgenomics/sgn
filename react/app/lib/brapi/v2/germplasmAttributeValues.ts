import * as z from "zod";
import { fetchResult, type ResultType } from "../utils.ts";

// This type is used to define the shape of our data.
export const Schema = z.object({
    attributeName: z.string(),
    value: z.string(),
});

export type SchemaType = z.infer<typeof Schema>;

/** `GET /programs/{programDbId}`
 * @param  {Object} params Parameters to provide to the call
 * @param  {String} germplasmDbId programDbId
 * @return {Schema}
 */

export async function search({germplasmDbId, params} : {germplasmDbId: Number, params?: Object}): Promise<ResultType> {
    let url = `/attributevalues?germplasmDbId=${germplasmDbId}`;
    if (params){
      let query = new URLSearchParams(params).toString();
      url += `?${query}`;
    }

    let result = await fetchResult({
        url: url,
        method: 'GET',
        errorMsg: 'Failed to fetch germplasm attributes detail.',
        successMsg: 'Succeeded in fetching germplasm attributes detail.'
    });

  if (result.data && result.data.result){
    console.log("result:", result.data.result.data);
    result.data.result = result.data.result.data.map( (record) => Schema.parse( record ));
    console.log("parsed:", result.data.result);
    //result.data.result = Schema.parse(result.data.result.data);
  }

  return result;

}
