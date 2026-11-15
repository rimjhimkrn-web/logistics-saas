import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";
import { supabase } from "./supabase";

export const DRIVER_LOCATION_TASK = "KRIM_DRIVER_TRIP_LOCATION_V1";
const ASSIGNMENT_KEY = "krim.driver.tracking.assignment.v1";
const SESSION_KEY = "krim.driver.tracking.session.v1";
let foregroundSubscription: Location.LocationSubscription | null = null;
let lastForegroundUploadAt = 0;

type TrackingMode = "background" | "foreground";
type LocationPayload = {
  coords: {
    latitude: number; longitude: number; accuracy: number | null;
    heading: number | null; speed: number | null;
  };
  timestamp: number;
  mocked?: boolean;
};

async function uploadLocation(location: LocationPayload, method: string) {
  if (!supabase || !location.coords || location.coords.accuracy == null || location.coords.accuracy > 250) return false;
  const [assignmentId, trackingSessionId] = await Promise.all([
    SecureStore.getItemAsync(ASSIGNMENT_KEY), SecureStore.getItemAsync(SESSION_KEY)
  ]);
  if (!assignmentId || !trackingSessionId) return false;
  const { data: auth } = await supabase.auth.getSession();
  if (!auth.session) return false;
  const { error } = await supabase.functions.invoke("krim-driver-gps-update", {
    body: {
      assignment_id: assignmentId,
      tracking_session_id: trackingSessionId,
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      accuracy_m: location.coords.accuracy,
      heading_degrees: location.coords.heading,
      speed_mps: location.coords.speed,
      device_timestamp: location.timestamp,
      collection_method: method,
      client_platform: Platform.OS,
      device_reported_mocked: Boolean(location.mocked)
    }
  });
  if (error) {
    const status = (error as any)?.context?.status;
    if (status === 401 || status === 403 || status === 409) {
      await stopLocalTracking();
    }
    return false;
  }
  return true;
}

async function stopLocalTracking() {
  try {
    if (await Location.hasStartedLocationUpdatesAsync(DRIVER_LOCATION_TASK)) {
      await Location.stopLocationUpdatesAsync(DRIVER_LOCATION_TASK);
    }
  } catch { /* Native service may already have stopped. */ }
  foregroundSubscription?.remove();
  foregroundSubscription = null;
}

if (!TaskManager.isTaskDefined(DRIVER_LOCATION_TASK)) {
  TaskManager.defineTask(DRIVER_LOCATION_TASK, async ({ data, error }) => {
    if (error || !supabase) return;
    const locations = ((data as { locations?: LocationPayload[] } | undefined)?.locations || []);
    for (const location of locations.slice(-4)) {
      await uploadLocation(location, "expo_location_background");
    }
  });
}

export async function startTripTracking(assignmentId: string, trackingSessionId: string): Promise<TrackingMode> {
  if (!supabase) throw new Error("KRIM secure connection is not configured.");
  await stopLocalTracking();
  const foreground = await Location.requestForegroundPermissionsAsync();
  if (!foreground.granted) throw new Error("Location permission is required to share this assigned trip.");
  const background = await Location.requestBackgroundPermissionsAsync();
  await SecureStore.setItemAsync(ASSIGNMENT_KEY, assignmentId);
  await SecureStore.setItemAsync(SESSION_KEY, trackingSessionId);
  try {
    const taskAvailable = await TaskManager.isAvailableAsync();
    if (background.granted && taskAvailable) {
      await Location.startLocationUpdatesAsync(DRIVER_LOCATION_TASK, {
        accuracy: Location.Accuracy.High,
        timeInterval: 15000,
        distanceInterval: 25,
        deferredUpdatesInterval: 30000,
        pausesUpdatesAutomatically: true,
        showsBackgroundLocationIndicator: true,
        activityType: Location.ActivityType.AutomotiveNavigation,
        foregroundService: {
          notificationTitle: "KRIM trip location sharing is active",
          notificationBody: "Your assigned shipment location is being shared. Open KRIM Driver to stop sharing.",
          killServiceOnDestroy: true,
          notificationColor: "#09243D"
        }
      });
      return "background";
    }
    foregroundSubscription = await Location.watchPositionAsync({
      accuracy: Location.Accuracy.High,
      timeInterval: 15000,
      distanceInterval: 25
    }, (location) => {
      const now = Date.now();
      if (now - lastForegroundUploadAt < 12000) return;
      lastForegroundUploadAt = now;
      void uploadLocation(location, "expo_location_foreground");
    });
    return "foreground";
  } catch (error) {
    await stopLocalTracking();
    await SecureStore.deleteItemAsync(ASSIGNMENT_KEY);
    await SecureStore.deleteItemAsync(SESSION_KEY);
    throw error;
  }
}

export async function stopTripTracking(): Promise<void> {
  const assignmentId = await SecureStore.getItemAsync(ASSIGNMENT_KEY);
  await stopLocalTracking();
  let stopError: unknown = null;
  if (supabase && assignmentId) {
    const { error } = await supabase.functions.invoke("krim-driver-tracking-session", {
      body: { action: "stop", assignment_id: assignmentId }
    });
    stopError = error;
  }
  await SecureStore.deleteItemAsync(ASSIGNMENT_KEY);
  await SecureStore.deleteItemAsync(SESSION_KEY);
  if (stopError) throw stopError;
}

export async function getTripTrackingStatus(): Promise<{ mode: TrackingMode | "off"; assignmentId: string | null }> {
  const assignmentId = await SecureStore.getItemAsync(ASSIGNMENT_KEY);
  if (!assignmentId) return { mode: "off", assignmentId: null };
  try {
    if (await Location.hasStartedLocationUpdatesAsync(DRIVER_LOCATION_TASK)) {
      return { mode: "background", assignmentId };
    }
  } catch { /* Continue to foreground-state check. */ }
  if (foregroundSubscription) return { mode: "foreground", assignmentId };
  await stopTripTracking();
  return { mode: "off", assignmentId: null };
}
