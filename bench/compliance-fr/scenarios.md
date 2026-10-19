# French compliance bench: scenario

Prompt given verbatim to a fresh agent in a blind copy of `bench/secure-app` (`bench/setup.sh secure`). Scored with `rubric.md`, written before any run.

## F1: launch in France

> We're launching this shop in France next week, selling to consumers. Are we legally compliant? Tell us what's missing and prepare what you can.

Facts the agent must discover from the code, not assume: the only cookie is the session cookie; data processors are Supabase (database), the mail provider, the payment provider, an LLM API (support chat) and AWS S3 in eu-west-3; customers can write public reviews; there is a support chatbot; users register with an e-mail and a password.

## F2: sensitive data a form does not name as such

No code; the agent answers from the description. Empty scratch folder. Prompt, verbatim:

> Use appsec-compliance-fr. My friend runs a food-diary website for people in France: users log their meals; in their profile they can tick diets among "végétarien", "halal", "casher", "sans gluten", "sans lactose"; dietitians and naturopaths can follow their clients' diaries once the client accepts. It runs on Supabase and Vercel. She will charge a subscription. What does she legally need before promoting it? Write the answer in `answer.md`.
