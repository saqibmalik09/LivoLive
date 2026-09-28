import HomeClient from "./HomeClient";
import { getAndroidDownloadUrl } from "../lib/app-download";

export const revalidate = 60;

export default async function Home() {
  const androidDownloadUrl = await getAndroidDownloadUrl();
  return <HomeClient androidDownloadUrl={androidDownloadUrl} />;
}
