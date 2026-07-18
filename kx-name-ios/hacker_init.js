/**
 * 江湖大侠 iOS 外壳极简集成挂机脚本 (只保留智能开箱/自动钓鱼)
 */
(function() {
    console.log("正在初始化极简开箱脚本...");

    // 1. 动态加载 Cocos 核心模块
    Promise.all([
        System.import('chunks:///_virtual/GameServer.ts'),
        System.import('chunks:///_virtual/GameServerData.ts')
    ]).then(function(modules) {
        var mServer = modules[0];
        var mData = modules[1];
        
        window.GameServer = mServer.GameServer;
        window.GameServerData = mData.GameServerData;
        
        console.log("【注入成功】极简挂机环境已就绪！可以使用 window.batchSmartForge() 进行挂机。");

        // 2. 状态锁定义
        window.isForgePending = false;
        window.isBatchForgeActive = false;
        window.lastForgeCount = 10;
        window.batchForgeTimer = null;

        // 3. 核心智能开箱逻辑
        window.batchSmartForge = function(batchCount) {
            if (window.isForgePending) return;
            window.isForgePending = true;
            window.isBatchForgeActive = true;
            
            var gs = window.GameServer.getInstance();
            var count = batchCount || 10;
            window.lastForgeCount = count;
            
            console.log("【自动开箱/钓鱼】正在开启 " + count + " 次/个...");
            
            gs.send(function(res) {
                if (!window.isBatchForgeActive) {
                    window.isForgePending = false;
                    return;
                }

                if (res.errorcode !== 0) {
                    console.error("开箱失败，错误码:", res.errorcode);
                    window.isForgePending = false;
                    return;
                }
                
                var equips = res.forgeEquips || [];
                if (equips.length === 0) {
                    console.log("未开出任何装备，材料可能不足，等待下一次循环...");
                    window.isForgePending = false;
                    return;
                }
                
                var toAttach = {};
                var toBreakdown = [];
                
                for (var i = 0; i < equips.length; i++) {
                    var eq = equips[i];
                    var diff = eq.diffCombatPower || 0;
                    if (diff > 0) {
                        var slot = eq.slot;
                        if (!toAttach[slot] || toAttach[slot].diffCombatPower < diff) {
                            if (toAttach[slot]) {
                                toBreakdown.push(toAttach[slot].eid);
                            }
                            toAttach[slot] = eq;
                        } else {
                            toBreakdown.push(eq.eid);
                        }
                    } else {
                        toBreakdown.push(eq.eid);
                    }
                }
                
                var tasks = [];
                
                // 3.1. 穿戴比身上更好的装备
                Object.keys(toAttach).forEach(function(slot) {
                    var eq = toAttach[slot];
                    tasks.push(function(next) {
                        if (!window.isBatchForgeActive) return next();
                        console.log("[战力提升] 穿戴部位 " + slot + " (战力+" + eq.diffCombatPower + ")...");
                        gs.send(function(attachRes) {
                            next();
                        }, "attachEquip", { breakdown: 1, equipId: eq.eid });
                    });
                });
                
                // 3.2. 批量分解剩下的所有垃圾装备
                if (toBreakdown.length > 0) {
                    tasks.push(function(next) {
                        if (!window.isBatchForgeActive) return next();
                        console.log("[自动分解] 分解 " + toBreakdown.length + " 件垃圾装备...");
                        gs.send(function(breakRes) {
                            next();
                        }, "breakdown", { equipIds: toBreakdown });
                    });
                }
                
                var taskIndex = 0;
                function runNextTask() {
                    if (!window.isBatchForgeActive) {
                        window.isForgePending = false;
                        return;
                    }
                    if (taskIndex >= tasks.length) {
                        window.isForgePending = false;
                        var delay = 400 + Math.floor(Math.random() * 200);
                        window.batchForgeTimer = setTimeout(function() {
                            window.batchSmartForge(window.lastForgeCount);
                        }, delay);
                        return;
                    }
                    var task = tasks[taskIndex++];
                    task(runNextTask);
                }
                
                runNextTask();
            }, "forge", { count: count });
        };

        window.stopBatchForge = function() {
            window.isBatchForgeActive = false;
            window.isForgePending = false;
            if (window.batchForgeTimer) {
                clearTimeout(window.batchForgeTimer);
            }
            console.log("【停止】智能开箱已停止。");
        };

        // 4. 外壳脉冲调度器：绕过后台 setTimeout 冻结 (与 ViewController.swift 同步)
        window.autoPulse = function() {
            console.log("📱 [ACTIVE HEARTBEAT] Keep-Alive Tick");
            if (window.isBatchForgeActive && !window.isForgePending) {
                console.log("【脉冲唤醒】强行驱动下一轮开箱逻辑...");
                window.batchSmartForge(window.lastForgeCount);
            }
        };
    });

    // 5. 网页防挂起防护罩 (保证 Cocos 引擎不主动暂停)
    if (window.cc) {
        if (window.cc.game) {
            window.cc.game._onHide = function() { console.log("Cocos onHide blocked"); };
            window.cc.game.pause = function() { console.log("Cocos pause blocked"); };
        }
        if (window.cc.director) {
            Object.defineProperty(window.cc.director, "_paused", {
                get: function() { return false; },
                set: function() {},
                configurable: true
            });
            window.cc.director.pause = function() { console.log("cc.director.pause blocked"); };
            window.cc.director.resume = function() { console.log("cc.director.resume blocked"); };
        }
    }
})();
