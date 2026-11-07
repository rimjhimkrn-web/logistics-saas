import React, { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Platform, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import {
  loadCustomerOrganizations,
  loadCustomerShipments,
  loadCustomerQuotes,
  loadShipmentTracking,
  type CustomerOrganization,
  type CustomerShipment,
  type CustomerQuote,
} from "./customerRepository";

type Props = { session: Session; onSignOut: () => void };
type Tracking = { shipment?: Record<string, unknown>; events?: Array<Record<string, unknown>>; milestones?: Array<Record<string, unknown>> };

const navy = "#071A35", blue = "#2366D9", teal = "#078B83", muted = "#687A90", line = "#E0E7F0";
const tabs = ["Home", "Shipments", "Quotes", "Track", "Account"] as const;
type Tab = typeof tabs[number];

export default function CustomerWorkspace({ session, onSignOut }: Props) {
  const [tab, setTab] = useState<Tab>("Home");
  const [organizations, setOrganizations] = useState<CustomerOrganization[]>([]);
  const [organizationId, setOrganizationId] = useState<number | null>(null);
  const [shipments, setShipments] = useState<CustomerShipment[]>([]);
  const [quotes, setQuotes] = useState<CustomerQuote[]>([]);
  const [tracking, setTracking] = useState<Tracking | null>(null);
  const [trackingShipment, setTrackingShipment] = useState("");
  const [loadingOrganizations, setLoadingOrganizations] = useState(true);
  const [loadingData, setLoadingData] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const refreshOrganizations = useCallback(async () => {
    if (!supabase) return;
    setLoadingOrganizations(true);
    setError("");
    try {
      const rows = await loadCustomerOrganizations(supabase, session.user.id);
      setOrganizations(rows);
      setOrganizationId((current) => rows.some((x) => x.id === current) ? current : (rows[0]?.id ?? null));
    } catch {
      setError("We could not load your authorized organizations. Please retry or contact KRIM support.");
    } finally {
      setLoadingOrganizations(false);
    }
  }, [session.user.id]);

  useEffect(() => { void refreshOrganizations(); }, [refreshOrganizations]);

  const refreshWorkspace = useCallback(async () => {
    if (!supabase || organizationId === null) {
      setShipments([]);
      setQuotes([]);
      return;
    }
    setLoadingData(true);
    setError("");
    try {
      const [shipmentRows, quoteRows] = await Promise.all([
        loadCustomerShipments(supabase, organizationId),
        loadCustomerQuotes(supabase, organizationId),
      ]);
      setShipments(shipmentRows);
      setQuotes(quoteRows);
    } catch {
      setError("Some workspace data could not be loaded. Access remains protected by KRIM authorization policies.");
    } finally {
      setLoadingData(false);
    }
  }, [organizationId]);

  useEffect(() => { void refreshWorkspace(); }, [refreshWorkspace]);

  const showTracking = async (shipmentNumber: string) => {
    if (!supabase) return;
    setTracking(null);
    setTrackingShipment(shipmentNumber);
    setTab("Track");
    setLoadingData(true);
    setError("");
    try {
      const result = await loadShipmentTracking(supabase, shipmentNumber);
      setTracking(result as Tracking);
    } catch {
      setError("Tracking is unavailable or your account is not authorized to view this shipment.");
    } finally {
      setLoadingData(false);
    }
  };

  const selectedOrganization = organizations.find((x) => x.id === organizationId);
  const openQuotes = quotes.filter((q) => q.status === "sent" && new Date(q.valid_until).getTime() > Date.now()).length;

  return (
    <View style={s.safe}>
      <View style={s.top}>
        <View><Text style={s.topBrand}>KRIM CUSTOMER</Text><Text style={s.topSub}>GLOBAL LOGISTICS OPERATING SYSTEM</Text></View>
        <Text style={s.signed}>● SECURE SESSION</Text>
      </View>
      <ScrollView contentContainerStyle={s.content}>
        <View style={s.info}><Text style={s.infoText}>LIVE READ-ONLY WORKSPACE · Shipment and quote visibility is retrieved from KRIM and restricted by your active organization permissions. Booking and payment actions remain gated.</Text></View>
        {!!error && <View style={s.errorBox}><Text style={s.errorText}>{error}</Text></View>}
        {!!notice && <View style={s.info}><Text style={s.infoText}>{notice}</Text></View>}

        <View style={s.panel}>
          <Text style={s.kicker}>AUTHORIZED ORGANIZATION</Text>
          {loadingOrganizations ? <ActivityIndicator color={blue}/> :
            organizations.length === 0 ? <Text style={s.muted}>No active organization membership was found for this account. Ask your organization administrator to invite you with the correct role.</Text> :
            <>
              <Text style={s.orgName}>{selectedOrganization?.display_name || selectedOrganization?.legal_name || "Select organization"}</Text>
              <Text style={s.tiny}>{selectedOrganization?.organization_type || "Organization"} · {selectedOrganization?.role || "Member"} · {selectedOrganization?.default_currency_code || "Currency not configured"} · {selectedOrganization?.timezone || "Timezone not configured"}</Text>
              <View style={s.orgChips}>{organizations.map((org) =>
                <Pressable key={org.id} onPress={() => { setOrganizationId(org.id); setTracking(null); }} style={[s.chip, organizationId === org.id && s.chipActive]}>
                  <Text style={[s.chipText, organizationId === org.id && s.chipTextActive]}>{org.display_name || org.legal_name}</Text>
                </Pressable>
              )}</View>
            </>}
        </View>

        {tab === "Home" && <>
          <Header kicker="CUSTOMER CONTROL CENTRE" title="Your logistics workspace" sub="Verified account information from the KRIM operating system."/>
          <View style={s.metrics}>
            <Metric title="Visible shipments" value={String(shipments.length)} detail="RLS-authorized records"/>
            <Metric title="Valid sent quotes" value={String(openQuotes)} detail="Not yet accepted or expired"/>
          </View>
          <View style={s.panel}>
            <Text style={s.panelTitle}>Recent shipments</Text>
            {loadingData ? <ActivityIndicator color={blue}/> : shipments.slice(0, 4).length ? shipments.slice(0, 4).map((x) =>
              <ShipmentRow key={x.id} shipment={x} onPress={() => void showTracking(x.shipment_number)}/>
            ) : <Text style={s.muted}>No shipment records are currently visible for this organization.</Text>}
            <Action title="View all shipments" onPress={() => setTab("Shipments")} secondary/>
          </View>
          <View style={s.panel}>
            <Text style={s.panelTitle}>How KRIM protects operations</Text>
            <Bullet text="Organization membership is checked by the backend."/>
            <Bullet text="Shipment and quote reads use existing row-level security."/>
            <Bullet text="Operational changes remain disabled until end-to-end controls are verified."/>
          </View>
        </>}

        {tab === "Shipments" && <>
          <Header kicker="SHIPMENT VISIBILITY" title="Your shipments" sub="Only records authorized for the selected organization are shown."/>
          {loadingData ? <ActivityIndicator color={blue}/> : shipments.length ? shipments.map((x) => <ShipmentRow key={x.id} shipment={x} onPress={() => void showTracking(x.shipment_number)}/>) : <Empty title="No visible shipments" body="No shipments are currently available for this organization, or your role does not have access."/>}
        </>}

        {tab === "Quotes" && <>
          <Header kicker="COMMERCIAL VISIBILITY" title="Quotes" sub="Amounts and currencies are displayed only from authorized KRIM quote records."/>
          {loadingData ? <ActivityIndicator color={blue}/> : quotes.length ? quotes.map((q) => <View key={q.id} style={s.panel}>
            <Text style={s.panelTitle}>Quote #{q.id}</Text>
            <Text style={s.amount}>{Number(q.amount).toLocaleString(undefined, { maximumFractionDigits: 2 })} {q.currency_code}</Text>
            <Text style={s.tiny}>Shipment ID {q.shipment_id} · Status: {q.status}</Text>
            <Text style={s.tiny}>Valid until: {new Date(q.valid_until).toLocaleString()}</Text>
            <Text style={s.tiny}>Commercial acceptance is not enabled in this app build.</Text>
          </View>) : <Empty title="No visible quotes" body="Confirmed quotes will appear here when available to your organization."/>}
        </>}

        {tab === "Track" && <>
          <Header kicker="AUTHORIZED TRACKING" title="Shipment tracking" sub="Select a shipment to retrieve its verified milestones."/>
          {trackingShipment ? <View style={s.panel}>
            <Text style={s.panelTitle}>Tracking: {trackingShipment}</Text>
            {loadingData ? <ActivityIndicator color={blue}/> : tracking ? <>
              <Text style={s.body}>{String(tracking.shipment?.status || "Status unavailable")}</Text>
              {(tracking.events || []).map((event, i) => <Bullet key={String(event.id ?? i)} text={String(event.event_type || "Shipment event") + " · " + (event.event_time ? new Date(String(event.event_time)).toLocaleString() : "Time not provided")}/>)}
              {(tracking.milestones || []).map((m, i) => <Bullet key={String(m.id ?? "m"+i)} text={String(m.milestone_type || "Milestone") + " · " + String(m.status || "Status unavailable")}/>)}
              {!tracking.events?.length && !tracking.milestones?.length && <Text style={s.muted}>No execution events have been recorded yet.</Text>}
            </> : <Text style={s.muted}>Tracking details have not been loaded.</Text>}
          </View> : <Empty title="Choose a shipment" body="Open a shipment from the Shipments tab to load its authorized tracking timeline."/>}
        </>}

        {tab === "Account" && <>
          <Header kicker="ACCOUNT SECURITY" title="Your account" sub={session.user.email || "Authenticated KRIM account"}/>
          <View style={s.panel}>
            <Text style={s.panelTitle}>Session and organization access</Text>
            <Text style={s.body}>Signed in successfully. Your app reads only active organization memberships visible to your authenticated account. Database policies remain the source of authorization.</Text>
            <Action title="Refresh account data" onPress={() => { void refreshOrganizations(); void refreshWorkspace(); }} secondary/>
            <Action title="Sign out securely" onPress={onSignOut}/>
          </View>
          <View style={s.panel}><Text style={s.panelTitle}>KRIM</Text><Text style={s.body}>Knowledge · Reliability · Integration · Movement</Text><Text style={s.tiny}>Global-ready architecture · Market availability requires local partner and compliance verification.</Text></View>
        </>}
      </ScrollView>
      <View style={s.nav}>{tabs.map((item) => <Pressable key={item} onPress={() => setTab(item)} accessibilityRole="tab" accessibilityState={{selected: tab === item}} style={s.navItem}>
        <Text style={[s.navIcon, tab === item && {color: blue}]}>{({Home:"⌂",Shipments:"▤",Quotes:"≋",Track:"◎",Account:"○"} as Record<Tab,string>)[item]}</Text>
        <Text style={[s.navLabel, tab === item && {color: blue}]}>{item}</Text>
      </Pressable>)}</View>
    </View>
  );
}

function Header({kicker,title,sub}:{kicker:string;title:string;sub:string}) { return <View style={s.header}><Text style={s.kicker}>{kicker}</Text><Text style={s.title}>{title}</Text><Text style={s.muted}>{sub}</Text></View>; }
function Metric({title,value,detail}:{title:string;value:string;detail:string}) { return <View style={s.metric}><Text style={s.muted}>{title}</Text><Text style={s.metricValue}>{value}</Text><Text style={s.tiny}>{detail}</Text></View>; }
function ShipmentRow({shipment,onPress}:{shipment:CustomerShipment;onPress:()=>void}) { return <Pressable onPress={onPress} style={s.shipment}><View style={{flex:1}}><Text style={s.panelTitle}>{shipment.shipment_number}</Text><Text style={s.body}>{shipment.origin_place_label || "Origin not specified"} → {shipment.destination_place_label || "Destination not specified"}</Text><Text style={s.tiny}>{shipment.requested_transport_mode || "Mode not specified"} · {shipment.status}</Text></View><Text style={s.open}>View ›</Text></Pressable>; }
function Bullet({text}:{text:string}) { return <View style={s.bullet}><Text style={s.bulletDot}>•</Text><Text style={s.body}>{text}</Text></View>; }
function Empty({title,body}:{title:string;body:string}) { return <View style={s.panel}><Text style={s.panelTitle}>{title}</Text><Text style={s.muted}>{body}</Text></View>; }
function Action({title,onPress,secondary=false}:{title:string;onPress:()=>void;secondary?:boolean}) { return <Pressable accessibilityRole="button" onPress={onPress} style={[s.action,secondary&&s.actionSecondary]}><Text style={[s.actionText,secondary&&{color:navy}]}>{title}</Text></Pressable>; }

const s = StyleSheet.create({
 safe:{flex:1,backgroundColor:"#F3F6FA"}, top:{backgroundColor:navy,paddingHorizontal:17,paddingVertical:14,flexDirection:"row",alignItems:"center",justifyContent:"space-between"},
 topBrand:{fontSize:13,fontWeight:"900",letterSpacing:1,color:"#fff"},topSub:{fontSize:8,letterSpacing:1.5,color:"#B9C9DA",marginTop:3},signed:{fontSize:9,fontWeight:"900",color:"#B9F2D7"},
 content:{padding:15,paddingBottom:28},info:{padding:12,borderRadius:11,backgroundColor:"#EAF2FF",marginBottom:12},infoText:{fontSize:10,lineHeight:16,color:"#234A7D"},
 errorBox:{padding:12,borderRadius:11,backgroundColor:"#FDECEC",marginBottom:12},errorText:{fontSize:11,lineHeight:16,color:"#9C2525"},
 panel:{backgroundColor:"#fff",borderWidth:1,borderColor:line,borderRadius:15,padding:15,marginBottom:12},kicker:{fontSize:10,fontWeight:"900",letterSpacing:1.4,color:teal,marginBottom:7},orgName:{fontSize:17,fontWeight:"900",color:navy},tiny:{fontSize:10,color:muted,marginTop:4,lineHeight:15},muted:{fontSize:12,color:muted,lineHeight:19},orgChips:{flexDirection:"row",flexWrap:"wrap",gap:7,marginTop:12},chip:{borderWidth:1,borderColor:line,borderRadius:18,paddingHorizontal:11,paddingVertical:8},chipActive:{backgroundColor:blue,borderColor:blue},chipText:{fontSize:10,fontWeight:"800",color:navy},chipTextActive:{color:"#fff"},
 header:{marginBottom:14},title:{fontSize:25,fontWeight:"900",letterSpacing:-.6,color:navy,marginBottom:5},metrics:{flexDirection:"row",gap:10,marginBottom:12},metric:{flex:1,backgroundColor:"#fff",borderWidth:1,borderColor:line,borderRadius:14,padding:13},metricValue:{fontSize:21,fontWeight:"900",color:navy,marginTop:7},panelTitle:{fontSize:13,fontWeight:"900",color:navy,marginBottom:7},body:{fontSize:11,color:muted,lineHeight:17},shipment:{flexDirection:"row",alignItems:"center",paddingVertical:12,borderBottomWidth:1,borderBottomColor:"#EEF1F5"},open:{fontSize:11,fontWeight:"900",color:blue},amount:{fontSize:20,fontWeight:"900",color:navy},bullet:{flexDirection:"row",gap:8,marginTop:8},bulletDot:{fontSize:16,color:teal},action:{minHeight:43,backgroundColor:blue,borderRadius:10,alignItems:"center",justifyContent:"center",paddingHorizontal:12,marginTop:10},actionSecondary:{backgroundColor:"#fff",borderWidth:1,borderColor:line},actionText:{fontSize:11,fontWeight:"900",color:"#fff"},
 nav:{flexDirection:"row",backgroundColor:"#fff",borderTopWidth:1,borderTopColor:line,paddingTop:8,paddingBottom:Platform.OS==="ios"?18:9},navItem:{flex:1,alignItems:"center",gap:3},navIcon:{fontSize:19,color:"#8391A4"},navLabel:{fontSize:8,fontWeight:"800",color:"#8391A4"}
});
