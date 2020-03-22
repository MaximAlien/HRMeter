//
//  ViewController.m
//  HRMeter
//
//  Created by Maxim Makhun on 9/16/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import CoreBluetooth;

#import "ViewController.h"

#define HEART_RATE_SERVICE @"180D"
#define HEART_RATE_MEASUREMENT @"2A37"

struct hrflags {
    uint8_t _hr_format_bit:1;
    uint8_t _sensor_contact_bit:2;
    uint8_t _energy_expended_bit:1;
    uint8_t _rr_interval_bit:1;
    uint8_t _reserved:3;
};

@interface ViewController () <CBPeripheralDelegate, CBCentralManagerDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"%s", __FUNCTION__);
    
    NSString *stateString;
    switch (self.centralManager.state) {
        case CBManagerStateResetting:
            stateString = @"Connection with service was lost. Resetting...";
            break;
        case CBManagerStateUnsupported:
            stateString = @"The platform doesn't support Bluetooth Low Energy.";
            break;
        case CBManagerStateUnauthorized:
            stateString = @"Application is not authorized to use Bluetooth Low Energy.";
            break;
        case CBManagerStatePoweredOff:
            stateString = @"Bluetooth is currently powered off.";
            break;
        case CBManagerStatePoweredOn:
            stateString = @"Bluetooth is currently powered on and available to use.";
            [self scanForPeripheral];
            break;
        case CBManagerStateUnknown:
        default:
            stateString = @"Unknown state.";
            break;
    }
    
    NSLog(@"State: %@", stateString);
}

- (void)scanForPeripheral {
    NSLog(@"%s", __FUNCTION__);
    
    CBUUID *heartRate = [CBUUID UUIDWithString:HEART_RATE_SERVICE];
    NSDictionary *scanOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                            forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    [self.centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:heartRate] options:scanOptions];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    NSLog(@"%s. Peripheral: %@. Advertisement data: %@", __FUNCTION__, peripheral, advertisementData);
    
    NSString *name = advertisementData[CBAdvertisementDataLocalNameKey];
    if (name) {
        NSLog(@"Found heart rate monitor: %@.", name);
        NSLog(@"Heart rate monitor RSSI: %@ db.", RSSI);
        
        [self.centralManager stopScan];
        
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        [central connectPeripheral:self.peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"%s", __FUNCTION__);
    
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    
    NSLog(@"State: %lu", (long)peripheral.state);
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (error) {
        NSLog(@"%s. Error: %@", __FUNCTION__, error);
        return;
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (error) {
        NSLog(@"%s. Error: %@", __FUNCTION__, error);
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"%s. Error: %@", __FUNCTION__, error);
        return;
    }
    
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:HEART_RATE_SERVICE]]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"%s. Error: %@", __FUNCTION__, error);
        return;
    }
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:HEART_RATE_SERVICE]]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HEART_RATE_MEASUREMENT]]) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"%s. Error: %@", __FUNCTION__, error);
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:HEART_RATE_MEASUREMENT]]) {
        const void *bytes = [characteristic.value bytes];
        const uint8_t *data = (uint8_t *)bytes;
        struct hrflags flags;
        memcpy(&flags, data, sizeof(flags));
        
        int hrValue = 0;
        int offset = sizeof(flags);
        memcpy(&hrValue, data + offset, flags._hr_format_bit + 1);
        offset += flags._hr_format_bit + 1;
        
        NSLog(@"Heart rate: %d", hrValue);
    }
}

@end
