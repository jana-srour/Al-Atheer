import webpush from "npm:web-push@3.6.7";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT")!,
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

Deno.serve(async (request) => {
  const dispatchSecret = Deno.env.get("DISPATCH_SECRET");
  if (
    !dispatchSecret ||
    request.headers.get("authorization") !== `Bearer ${dispatchSecret}`
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { data: dueItems, error: dueError } = await supabase
    .from("azkar")
    .select("id,title,content,description,source,repetition_count,scheduled_at")
    .is("notification_sent_at", null)
    .lte("scheduled_at", new Date().toISOString());
  if (dueError) {
    console.error("Could not load due Azkar reminders", dueError);
    return Response.json({ error: dueError.message }, { status: 500 });
  }

  const { data: subscriptions, error: subscriptionError } = await supabase
    .from("web_push_subscriptions")
    .select("endpoint,subscription,sound_enabled");
  if (subscriptionError) {
    console.error("Could not load web push subscriptions", subscriptionError);
    return Response.json({ error: subscriptionError.message }, { status: 500 });
  }

  const failures: string[] = [];
  for (const item of dueItems ?? []) {
    const body = [
      item.content,
      item.description,
      item.source,
      `يكرر ${item.repetition_count} مرات`,
    ].filter(Boolean).join("\n\n");
    for (const entry of subscriptions ?? []) {
      try {
        await webpush.sendNotification(
          entry.subscription,
          JSON.stringify({
            title: item.title,
            body,
            soundEnabled: entry.sound_enabled,
            tag: `azkar-${item.id}`,
            url: "../",
          }),
        );
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        if (statusCode === 404 || statusCode === 410) {
          const { error: deleteError } = await supabase
            .from("web_push_subscriptions")
            .delete()
            .eq("endpoint", entry.endpoint);
          if (deleteError) failures.push(deleteError.message);
        } else {
          failures.push(String(error));
        }
      }
    }

    const { error: markError } = await supabase
      .from("azkar")
      .update({ notification_sent_at: new Date().toISOString() })
      .eq("id", item.id)
      .is("notification_sent_at", null);
    if (markError) failures.push(markError.message);
  }

  if (failures.length > 0) {
    console.error("Some Azkar push deliveries failed", failures);
  }
  return Response.json({ sent: dueItems?.length ?? 0, failures });
});
