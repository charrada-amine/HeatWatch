#ifndef CSENSORS_H
#define CSENSORS_H

typedef struct {
    char name[64];
    double celsius;
} hw_sensor_reading;

/// Fills `out` with up to `max` temperature readings. Returns how many were written.
int hw_read_temperatures(hw_sensor_reading *out, int max);

#endif
