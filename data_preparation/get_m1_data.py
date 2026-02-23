import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime

master_df = pd.read_csv('./src_csv/m1_master.csv')
master_df['time'] = pd.to_datetime(master_df['time'])
latest_time = master_df['time'].max()
symbol = "XAUUSD"


mt5.initialize()


server_ts = mt5.symbol_info(symbol).time
server_now = datetime.fromtimestamp(server_ts)
rates = mt5.copy_rates_range(
    symbol,
    mt5.TIMEFRAME_M1,
    latest_time,
    server_now
)

if rates is None or len(rates) == 0:
    print("No data:", mt5.last_error())
else:
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    df = df[['time','open','high','low','close','tick_volume']]
    
    
mt5.shutdown()


final_df = pd.concat([master_df,df])
final_df = final_df.drop_duplicates(subset='time', keep='first')

final_df.to_csv(f"./src_csv/m1_master.csv", index=False)
print(f'Get data from "{latest_time}" to "{server_now.strftime("%Y.%m.%d %H:%M")}" | Total_rows: {len(df)}')
