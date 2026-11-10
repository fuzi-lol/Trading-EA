double CalculateLotSize(double sl_points) {
      double risk_amount = AccountObj.Balance() * (InpRiskPerTrade / 100.0);
      double tick_value = SymbolObj.TickValue();
      double lot_step = SymbolObj.LotStep();
      double calculated_lot = risk_amount / (sl_points * tick_value);
      return MathFloor(calculated_lot / lot_step) * lot_step;
   }