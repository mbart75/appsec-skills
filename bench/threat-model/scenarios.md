# Threat-model bench: scenarios

Two prompts, given verbatim to a fresh agent. Scored with `rubric.md`, written before any run.

## S1: new application, no code yet (scope: project)

Run in an empty git repository.

> I'm about to build a booking app for a hair salon. Customers create an account, book an appointment and pay a 20 € deposit with Stripe. They get SMS reminders the day before. The salon owner has an admin dashboard to manage the calendar, see customers and issue refunds. There is also an AI assistant on the site that answers questions and can reschedule a customer's appointment. Stack: Next.js on Vercel, Supabase (Postgres + Auth), Stripe, Twilio for SMS, an LLM API for the assistant. Nothing is coded yet. Before I start, do the threat model and give me the security requirements I should build in.

## S2: new feature on existing code (scope: feature)

Run in a blind copy of `bench/secure-app` (`bench/setup.sh secure`).

> We're adding gift cards to this shop: a customer buys a gift card (10 to 200 €), receives a code by e-mail, and anyone with the code can spend its balance at checkout, in one or several orders. Before we implement it, give us the security requirements for this feature.
