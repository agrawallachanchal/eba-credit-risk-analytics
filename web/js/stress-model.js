// Stress model, same arithmetic as model/EBA_stress_test_model.xlsx (sheet Stress).
// Headline (instant loss): CET1 minus provisions on new NPE, RWA constant.
// With earnings: run-rate profit before tax over the horizon, 30% tax on positive results only,
// 30% payout in profit years and none in loss years (EBA 2025 methodology, para. 32 and Table 1).

export function stressBank(bank, shock, horizon, a) {
  const newNpe = shock * bank.gross_loans;
  const provisions = newNpe * bank.npe_coverage;
  const cet1Today = bank.cet1_capital / bank.rwa;
  const headroomToday = cet1Today - bank.cet1_requirement;

  const stressedInstant = (bank.cet1_capital - provisions) / bank.rwa;

  const earnings = bank.pbt_h1 * a.annualisation * horizon;
  const preTax = earnings - provisions;
  const tax = Math.max(preTax, 0) * a.tax_rate;
  const net = preTax - tax;
  const distributions = net > 0 ? net * a.payout_profit : 0; // payout ratio in loss years is 0
  const stressedEarnings = (bank.cet1_capital + net - distributions) / bank.rwa;

  return {
    newNpe, provisions, cet1Today, headroomToday,
    instant: { ratio: stressedInstant, headroom: stressedInstant - bank.cet1_requirement },
    earnings: { ratio: stressedEarnings, headroom: stressedEarnings - bank.cet1_requirement, net, distributions },
  };
}

export function median(xs) {
  const s = [...xs].sort((p, q) => p - q);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
