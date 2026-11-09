import "react-native-url-polyfill/auto";
import { createClient, type SupportedStorage } from "@supabase/supabase-js";
import * as SecureStore from "expo-secure-store";
const url = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "";
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
const SIZE = 1800;
const storage: SupportedStorage = {
 async getItem(k) {
  const n = await SecureStore.getItemAsync(k + ".count");
  if (!n) return SecureStore.getItemAsync(k);
  const count = Number(n);
  if (!Number.isInteger(count) || count < 1 || count > 20) return null;
  const parts = await Promise.all(Array.from({length:count},(_,i)=>SecureStore.getItemAsync(k+"."+i)));
  if (parts.some(x=>x===null)) return null;
  return (parts as string[]).join("");
 },
 async setItem(k,v) {
  await this.removeItem(k);
  if (v.length <= SIZE) return SecureStore.setItemAsync(k,v);
  const count = Math.ceil(v.length/SIZE);
  for(let i=0;i<count;i++) await SecureStore.setItemAsync(k+"."+i,v.slice(i*SIZE,(i+1)*SIZE));
  await SecureStore.setItemAsync(k+".count",String(count));
 },
 async removeItem(k) {
  const n=await SecureStore.getItemAsync(k+".count");
  if(n){const count=Math.min(Number(n),20);for(let i=0;i<count;i++)await SecureStore.deleteItemAsync(k+"."+i);await SecureStore.deleteItemAsync(k+".count");}
  await SecureStore.deleteItemAsync(k);
 }
};
export const supabaseConfigured=Boolean(url&&key);
export const supabase=supabaseConfigured?createClient(url,key,{auth:{storage,autoRefreshToken:true,persistSession:true,detectSessionInUrl:false,flowType:"pkce"}}):null;
