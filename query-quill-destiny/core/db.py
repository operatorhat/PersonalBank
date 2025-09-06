import sqlite3, time
from pathlib import Path
from typing import List, Dict, Tuple
import pandas as pd

class DestinyDatabase:
    def __init__(self, db_path="data/processed/destiny2.db", seed=True):
        self.path = Path(db_path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.path)
        self.conn.row_factory = sqlite3.Row
        self._create_tables()
        if seed: self._seed()

    def _create_tables(self):
        self.conn.executescript("""
        CREATE TABLE IF NOT EXISTS players(
        player_id INTEGER PRIMARY KEY,
        display_name TEXT, platform TEXT,
total_playtime_hours INT
        );
        CREATE TABLE IF NOT EXISTS weapons(
            weapon_id INTEGER PRIMARY KEY,
            weapon_name TEXT, weapon_type TEXT, rpm INT, impact INT
        );
        CREATE TABLE IF NOT EXISTS weapon_usage(
        usage_id INTEGER PRIMARY KEY,
        player_id INT, weapon_id INT, kills INT,
        FOREIGN KEY(player_id) REFERENCES
players(player_id)
        FOREIGN KEY(weapon_id) REFERENCES weapons(weapon_id)
    );
    """)
        self.conn.executemany(
         "INSERT OR IGNORE INTO players VALUES(?,?,?,?)",
         [(1,"ArcTitan","Steam",520),
          (2,"VoidLock","Xbox",340)]
        )
        self.conn.executemany(
           "INSERT OR IGNORE INTO weapons VALUES(?,?,?,?,?)",
         [(1,"Fatebringer","Hand Cannon",140,84),
          (2,"Palindrome","Hand Cannon",140,84),
          (3,"The Last Word","Hand Cannon",225,68)]
        )
        self.conn.executemany(
         "INSERT OR IGNORE INTO weapon_usage VALUES(?,?,?,?,?)",
          [(1,1,1,60),
           (2,1,2,45),
           (3,2,3,12)]  
        )
        self.conn.commit()

    def table_info(self)->Dict[str,List[str]]:
        cur = self.conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        tables = [r[0] for r in cur.fetchall()]
        meta={}
        for t in tables:
            cur.execute(f"PRAGMA table_info({t})")
            meta[t]=[c[1] for c in cur.fetchall()]
        return meta

    def _is_safe(self, q:str)->Tuple[bool,str]:
        ql=q.strip().lower()
        if not ql.startswitch("select"): return False,"Only SELECT allowed"
        forbidden=["update ","delete ","insert ","drop ","alter ","pragma "]
        if any(f in ql for f in forbidden): return False,"Forbidden keyword"
        if ql.count(";")>1: return False,"Multiple statements"
        return True,"ok"

    def query(self, q:str):
        safe,msg=self._is_safe(q)
        if not safe: return pd.DataFrame(), False, msg
        import time; st=time.time()
        try:
            df=pd.read_sql_query(q,self.conn)
            return df,True,f"ok {len(df)} rows { (time.time()-st)*1000:.1f}ms"
        except Exception as e:
            return pd.DataFrame(),False,str(e)
       # quick test
    class DestinyDatabase:
        def __init__(self, db_path="data/processed/destiny2.db", seed=True):
            if __name__ == "__main__":
                db = DestinyDatabase()
                print(db.table_info())
                print(db.query("""
                SELECT weapon_name, kills 
                FROM weapons 
                JOIN weapon_usage USING(weapon_id) 
                LIMIT 5;
                """)) 
