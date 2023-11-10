#!/bin/bash
set -e

clickhouse client --user default \
--password secret \
-n <<-EOSQL
    CREATE DATABASE IF NOT EXISTS vitalsigns;
    SET flatten_nested=0;
    CREATE TABLE IF NOT EXISTS vitalsigns.sleep
    (
        start_time DateTime64,
        end_time DateTime64,
        all_time_in_seconds Int32,
        delay_in_seconds Int32,
        efficiency_in_percents Int32,
        periods_of_wakefulness Int32,
        poses Array(String),
        stages Array(Tuple(stage String, start_time DateTime64, end_time DateTime64))
    ) ENGINE = MergeTree ORDER BY tuple();
    CREATE TABLE IF NOT EXISTS vitalsigns.vitalsigns
    (
        time DateTime64,
        heartRate_out Float32,
        breathRate_out Float32,
        heartRate_CM Float32,
        heartRate_4Hz_CM Float32,
        heartRate_xCorr_CM Float32
    ) ENGINE = MergeTree ORDER BY (time);
    CREATE TABLE IF NOT EXISTS vitalsigns.vitalsigns_queue
    (
        time DateTime64,
        heartRate_out Float32,
        breathRate_out Float32,
        heartRate_CM Float32,
        heartRate_4Hz_CM Float32,
        heartRate_xCorr_CM Float32
    ) ENGINE = Kafka('kafka1:9092', 'messages', 'clickhouse', 'JSONEachRow') settings kafka_thread_per_consumer = 0, kafka_num_consumers = 1;
    CREATE MATERIALIZED VIEW IF NOT EXISTS vitalsigns.vitalsigns_mv TO vitalsigns.vitalsigns AS
    SELECT * 
    FROM vitalsigns.vitalsigns_queue;
    INSERT INTO vitalsigns.sleep FROM INFILE '/test-data/test-sleep-data.json' FORMAT JSONEachRow;
    INSERT INTO vitalsigns.vitalsigns FROM INFILE '/test-data/test-data.csv' FORMAT CSV;
EOSQL