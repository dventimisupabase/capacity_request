-- One-time: Set WEB_APP_BASE_URL in Vault for "View in Web" button in Block Kit
SELECT vault.create_secret(
  'https://oandzthkyemwojhebqwc.supabase.co/storage/v1/object/public/www',
  'WEB_APP_BASE_URL'
);
