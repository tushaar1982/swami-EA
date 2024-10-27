
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include  <Trade/Trade.mqh>

CTrade            trade;
CPositionInfo     pos;  
COrderInfo        ord; 
  
  
   input group "=== Trading Inputs  ==="

          input double         RiskPercen      = 60;  // Risk as % of Trading Capital
          input int            Tppoints        = 1000; // Take profit (10 point = 1 pips)
          input int            Slpoints        = 200; // Stoploss points (10 points = 1 pip)
          input int            TslTriggerpoint = 15;  // Points in profit before Trailing SL activated (10 point = 1 pip) 
          input int            Tslpoint        = 10; // Trailing stop loss (10 point = 1 pip)
          input ENUM_TIMEFRAMES  Tmeframe = PERIOD_CURRENT;  //Time freme to run 
          input int            InpMagic = 298347;    //EA identification no 
          input string               TradeComment = "Scalping Robot";

          enum StartHour  {Inactive =0, _1500= 15, }; 
         
          input StartHour SHInput=0; // Start Hour 
        
          enum EndHour {Inactive = 0, _2100=21, };

          input EndHour EHInput=0; // End Hour
          
          int SHChoice;         
          int EHChoice;

          int           BarsN = 5;
          int           ExpirationBars = 100;
          int           OrderDistPoints   = 100;







int OnInit(){

    trade.SetExpertMagicNumber(InpMagic);   
   
    ChartSetInteger(0,CHART_SHOW_GRID,false);
 
 return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
 }


void OnTick(){



  if(!IsNewBar()) return;

  MqlDateTime time;
  TimeToStruct(TimeCurrent(),time);
  
  int Hournow = time.hour;
  
  SHChoice = SHInput;
  EHChoice = EHInput;
  
  if(Hournow<SHChoice){CloseAllOrder();return;}  
  if(Hournow>EHChoice && EHChoice!=0){CloseAllOrder(); return;}
  
  int BuyTotal=0; 
  int SellTotal=0;
  
  for (int i=PositionsTotal()-1; i>=0; i--){
      pos.SelectByIndex(i);
      if(pos.PositionType()==POSITION_TYPE_BUY && pos.Symbol()==_Symbol && pos.Magic()==InpMagic) BuyTotal++;
      if(pos.PositionType()==POSITION_TYPE_SELL && pos.Symbol()==_Symbol && pos.Magic()==InpMagic) SellTotal++;
  }
   for (int i=OrdersTotal()-1; i>=0; i--){
    ord.SelectByIndex(i);                                          
    if(ord.OrderType()==ORDER_TYPE_BUY_STOP && ord.Magic()==InpMagic) BuyTotal++;
    if(ord.OrderType()==ORDER_TYPE_SELL_STOP && ord.Magic()==InpMagic) SellTotal++;
  }
  
   if(BuyTotal <=0){ 
      double high = findHigh();
      if(high > 0){
         SendBuyOrder(high);
     }    
   }  
   
   if(SellTotal <=0){
       double low = findLow();
       if(low > 0){
           SendSellOrder(low);
       } 
    }  
  
 
}
 
 
 
double findHigh(){
   double highestHigh = 0;
   for(int i = 0; i < 200; i++){
       double high = iHigh(_Symbol,Tmeframe,i);
       if(i > BarsN && iHighest(_Symbol,Tmeframe,MODE_HIGH,BarsN*2+1,i-BarsN) == i){
           if(high > highestHigh){
              return high;
           }
      }
      highestHigh = MathMax(high,highestHigh);  
    }     
    return -1;       
}

double findLow(){
   double lowestLow = DBL_MAX;
   for(int i = 0; i < 200; i++){
       double low = iLow(_Symbol,Tmeframe,i);
       if(i > BarsN && iLowest(_Symbol,Tmeframe,MODE_LOW,BarsN*2+1,i-BarsN) ==i){
          if(low < lowestLow){
             return low;
          }
       }
       lowestLow = MathMin(low,lowestLow);
   }
     return -1;
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currenTime = iTime(_Symbol,PERIOD_CURRENT,0);
    if(previousTime!=currenTime){
       previousTime=currenTime;
      return true;
   }
   return false;
}

void SendBuyOrder(double entry){

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
   if(ask > entry - OrderDistPoints * _Point) return;

   double tp = entry + Tppoints * _Point;
   double sl = entry - Slpoints * _Point;

   double lots = 0.01;
   if(RiskPercen > 0) lots = calcLots(entry-sl);
   
   datetime expiration = iTime(_Symbol,Tmeframe,0) + ExpirationBars * PeriodSeconds(Tmeframe);

     trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);

}

void SendSellOrder(double entry){

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid < entry + OrderDistPoints * _Point) return;
   
   double tp = entry - Tppoints *_Point;
   
   double sl = entry + Slpoints* _Point;
   
   double lots = 0.01;
   if(RiskPercen > 0) lots = calcLots(sl-entry);
   
   datetime expiration = iTime(_Symbol,Tmeframe,0) + ExpirationBars * PeriodSeconds(Tmeframe);

   trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);
   
}   
   
   
   
   
double calcLots(double slpoint){
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercen / 100;
   
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minvolume = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double maxvolume = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   double volumelimit = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   
   
   
   double moneyPerLotstep = Slpoints / ticksize * tickvalue * lotstep;
   double lots = MathFloor(risk/ moneyPerLotstep) * lotstep;
   
   if(volumelimit!=0) lots = MathMin(lots,volumelimit);
   if(maxvolume!=0) lots = MathMin(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   if(minvolume!=0) lots = MathMax(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble(lots,2);
   
   return lots;
}



void CloseAllOrder(){

    for(int i=OrdersTotal()-1;i>=0;i--){  
        ord.SelectByIndex(i);
      ulong ticket = ord.Ticket();
      if(ord.Symbol()==_Symbol && ord.Magic()==InpMagic){
       trade.OrderDelete(ticket);
     }
   }

}
