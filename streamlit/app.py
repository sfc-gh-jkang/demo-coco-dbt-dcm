"""
PawCore SmartCollar Health Dashboard
=====================================
A Streamlit-in-Snowflake app showing lot health, battery trends, and customer satisfaction.

Deploy to Snowflake:
  CREATE STAGE IF NOT EXISTS PAWCORE_ANALYTICS.PUBLIC.STREAMLIT_STAGE;
  PUT 'file:///path/to/streamlit/app.py' @PAWCORE_ANALYTICS.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
  PUT 'file:///path/to/streamlit/environment.yml' @PAWCORE_ANALYTICS.PUBLIC.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

  CREATE OR REPLACE STREAMLIT PAWCORE_ANALYTICS.PUBLIC.PAWCORE_DASHBOARD
    ROOT_LOCATION = '@PAWCORE_ANALYTICS.PUBLIC.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'PAWCORE_DEMO_WH';

Or via CLI:
  snow streamlit deploy --connection <conn>
"""

import streamlit as st

st.set_page_config(page_title="PawCore Health Dashboard", layout="wide")

# ─── Connection ──────────────────────────────────────────────────────────────
conn = st.connection("snowflake")
session = conn.session()


# ─── Data loading (cached) ───────────────────────────────────────────────────
@st.cache_data(ttl=300)
def load_lot_data():
    return session.sql("""
        SELECT lot_number, pass_rate, avg_battery_level, low_battery_incidents,
               device_count, avg_temperature, avg_humidity
        FROM PAWCORE_ANALYTICS.ANALYTICS.MART_LOT_QUALITY_CORRELATION
        ORDER BY avg_battery_level ASC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_regional_data():
    return session.sql("""
        SELECT lot_number, region, avg_rating, review_count, avg_battery_level, device_count
        FROM PAWCORE_ANALYTICS.ANALYTICS.MART_REGIONAL_CUSTOMER_IMPACT
        ORDER BY avg_rating ASC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_moisture_data():
    return session.sql("""
        SELECT lot_number, region, avg_humidity, avg_battery, moisture_resistance
        FROM PAWCORE_ANALYTICS.ANALYTICS.MART_BATTERY_MOISTURE_CORRELATION
        ORDER BY avg_battery ASC
    """).to_pandas()


@st.cache_data(ttl=300)
def load_telemetry_summary():
    return session.sql("""
        SELECT COUNT(DISTINCT device_id) AS total_devices,
               COUNT(*) AS total_readings,
               ROUND(AVG(battery_level), 1) AS avg_battery
        FROM PAWCORE_ANALYTICS.DEVICE_DATA.TELEMETRY
    """).to_pandas()


# ─── Load data ───────────────────────────────────────────────────────────────
df_lot = load_lot_data()
df_regional = load_regional_data()
df_moisture = load_moisture_data()
df_summary = load_telemetry_summary()

# ─── Sidebar ─────────────────────────────────────────────────────────────────
st.sidebar.title("Filters")
lot_filter = st.sidebar.selectbox(
    "Lot", ["ALL"] + sorted(df_lot["LOT_NUMBER"].tolist())
)

st.sidebar.markdown("---")
st.sidebar.markdown("**Data source:** `PAWCORE_ANALYTICS`")
st.sidebar.markdown("**Refreshes:** every 5 minutes")

# ─── Header ──────────────────────────────────────────────────────────────────
st.title("PawCore SmartCollar Health Dashboard")
st.caption("Real-time manufacturing quality + field performance + customer satisfaction")

# ─── KPI Cards ───────────────────────────────────────────────────────────────
col1, col2, col3, col4 = st.columns(4)

total_devices = int(df_summary["TOTAL_DEVICES"].iloc[0])
total_readings = int(df_summary["TOTAL_READINGS"].iloc[0])
avg_battery = float(df_summary["AVG_BATTERY"].iloc[0])
worst_lot = df_lot.iloc[0]["LOT_NUMBER"]

col1.metric("Total Devices", f"{total_devices:,}")
col2.metric("Total Readings", f"{total_readings:,}")
col3.metric("Avg Battery", f"{avg_battery}%")
col4.metric("Worst Lot", worst_lot, delta=f"{df_lot.iloc[0]['AVG_BATTERY_LEVEL']:.1f}%", delta_color="inverse")

st.markdown("---")

# ─── Battery by Lot (bar chart) ──────────────────────────────────────────────
st.subheader("Average Battery Level by Lot")

if lot_filter == "ALL":
    chart_data = df_lot[["LOT_NUMBER", "AVG_BATTERY_LEVEL"]].set_index("LOT_NUMBER")
else:
    chart_data = df_lot[df_lot["LOT_NUMBER"] == lot_filter][["LOT_NUMBER", "AVG_BATTERY_LEVEL"]].set_index("LOT_NUMBER")

st.bar_chart(chart_data, color="#29B5E8")

# ─── Two-column layout ───────────────────────────────────────────────────────
left, right = st.columns(2)

# ─── Customer Ratings ────────────────────────────────────────────────────────
with left:
    st.subheader("Customer Ratings by Region")
    if lot_filter == "ALL":
        display_regional = df_regional
    else:
        display_regional = df_regional[df_regional["LOT_NUMBER"] == lot_filter]

    st.dataframe(
        display_regional[["LOT_NUMBER", "REGION", "AVG_RATING", "REVIEW_COUNT"]],
        use_container_width=True,
        hide_index=True,
    )

# ─── Moisture Correlation ────────────────────────────────────────────────────
with right:
    st.subheader("Humidity vs Battery (Moisture Correlation)")
    if lot_filter == "ALL":
        display_moisture = df_moisture
    else:
        display_moisture = df_moisture[df_moisture["LOT_NUMBER"] == lot_filter]

    st.dataframe(
        display_moisture[["LOT_NUMBER", "REGION", "AVG_HUMIDITY", "AVG_BATTERY", "MOISTURE_RESISTANCE"]],
        use_container_width=True,
        hide_index=True,
    )

# ─── Lot Detail Table ────────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Lot Quality Summary")

if lot_filter == "ALL":
    display_lot = df_lot
else:
    display_lot = df_lot[df_lot["LOT_NUMBER"] == lot_filter]

st.dataframe(
    display_lot[["LOT_NUMBER", "PASS_RATE", "AVG_BATTERY_LEVEL", "LOW_BATTERY_INCIDENTS", "DEVICE_COUNT"]],
    use_container_width=True,
    hide_index=True,
)

# ─── Scatter: Humidity vs Battery ────────────────────────────────────────────
st.markdown("---")
st.subheader("Humidity vs Battery Level (per lot)")

scatter_data = df_moisture.rename(columns={
    "AVG_HUMIDITY": "Humidity (%)",
    "AVG_BATTERY": "Battery (%)",
    "LOT_NUMBER": "Lot",
})
st.scatter_chart(scatter_data, x="Humidity (%)", y="Battery (%)", color="Lot")

# ─── Footer ──────────────────────────────────────────────────────────────────
st.markdown("---")
st.caption("Built with Streamlit-in-Snowflake | Data: PAWCORE_ANALYTICS semantic view | Agent: PAWCORE_ASSISTANT")
