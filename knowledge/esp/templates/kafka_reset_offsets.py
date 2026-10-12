#!/usr/bin/env python3
"""
kafka_reset_offsets.py: reset a Kafka consumer group to the EARLIEST (low watermark)
offset on every partition so that an ESP Kafka connector replays the topic.

Usage (PowerShell):
    $env:KAFKA_BOOTSTRAP="host:9092"; $env:KAFKA_USER="..."; $env:KAFKA_PASS="..."
    python kafka_reset_offsets.py <topic> <consumer-group>

IMPORTANT:
  * STOP the ESP project (or any consumer in the group) first. Confluent Cloud rejects
    offset commits for an active group.
  * "Earliest" = the low watermark, which moves forward with broker retention.
Requires: pip install confluent-kafka
"""
import os
import sys

from confluent_kafka import Consumer, TopicPartition


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    topic, group = sys.argv[1], sys.argv[2]
    conf = {
        "bootstrap.servers": os.environ["KAFKA_BOOTSTRAP"],
        "security.protocol": os.environ.get("KAFKA_SECURITY_PROTOCOL", "SASL_SSL"),
        "sasl.mechanism": os.environ.get("KAFKA_SASL_MECHANISM", "PLAIN"),
        "sasl.username": os.environ["KAFKA_USER"],
        "sasl.password": os.environ["KAFKA_PASS"],
        "group.id": group,
        "enable.auto.commit": False,
    }
    consumer = Consumer(conf)
    md = consumer.list_topics(topic=topic, timeout=10)
    if topic not in md.topics or md.topics[topic].error is not None:
        consumer.close()
        sys.exit(f"Topic '{topic}' not found or not authorized.")

    offsets = []
    for pid in sorted(md.topics[topic].partitions):
        low, high = consumer.get_watermark_offsets(TopicPartition(topic, pid), timeout=10)
        print(f"partition {pid}: low={low} high={high} -> reset to {low} ({high - low} msgs available)")
        offsets.append(TopicPartition(topic, pid, low))

    consumer.commit(offsets=offsets, asynchronous=False)
    consumer.close()
    print(f"Group '{group}' reset to earliest on topic '{topic}'.")


if __name__ == "__main__":
    main()
