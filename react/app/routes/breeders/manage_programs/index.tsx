import { columns } from "./table/columns";
import {DataTable } from "@/components/ui/DataTable"
import type { Route } from "./+types/";
import { Schema, type SchemaType } from "@/lib/brapi/v2/programs";
import {Page} from "./page";

export async function clientLoader({}: Route.ClientLoaderArgs) {
  const clientData = await getData();
  //await new Promise(resolve => setTimeout(resolve, 2000));
  return clientData;
}

clientLoader.hydrate = true as const;

async function getData(): Promise<SchemaType[]> {
  // Fetch data from your API here.

  return Array(100).fill(0).map((_, i) => {
    return Schema.parse({
        programDbId: String(i + 1),
        programName: `${i} Name`,
        objective: `${i} Objective`,
        abbreviation: `${i} Abbreviation`,
    })
  });
}

const caption = "List of breeding programs.";

export function HydrateFallback() {
  return (
    <Page>
      <DataTable columns={columns} data={[]} skeleton={true} caption={caption} />
    </Page>
  )
}

export default function Component({loaderData}) {

  return (
    <Page>
      <DataTable columns={columns} data={loaderData} skeleton={false} caption={caption} />
    </Page>
  )
}
