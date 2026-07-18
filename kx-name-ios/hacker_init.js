/**
 * 江湖大侠 iOS 外壳极简集成挂机脚本 (只保留智能开箱/自动钓鱼)
 */
(function() {
    console.log("正在初始化极简开箱脚本...");

    // 1. 动态加载 Cocos 核心模块
    Promise.all([
        System.import('chunks:///_virtual/GameServer.ts'),
        System.import('chunks:///_virtual/GameServerData.ts'),
        System.import('chunks:///_virtual/LocaleData.ts')
    ]).then(function(modules) {
        window.GameServer = modules[0].GameServer;
        window.GameServerData = modules[1].GameServerData;
        window.LocaleData = modules[2].LocaleData;
        
        console.log("【注入成功】极简挂机环境已就绪！可以使用 window.batchSmartForge() 进行挂机。");

        // 2. 状态锁定义
        window.isForgePending = false;
        window.isBatchForgeActive = false;
        window.lastForgeCount = 1;
        window.batchForgeTimer = null;

        // 3. 核心智能开箱逻辑
        window.batchSmartForge = function(batchCount) {
            if (window.isForgePending) return;
            window.isForgePending = true;
            window.isBatchForgeActive = true;
            
            var gs = window.GameServer.getInstance();
            var gd = window.GameServerData.getInstance();
            
            // 3.1 动态边界检查：获取当前角色的实际体力，防止体力不足导致 10600 报错
            var staminaId = window.LocaleData.getEvolutionRoot().staminaItemId;
            var currentStamina = gd.getItemCountByProtoId(staminaId) || 0;
            
            if (currentStamina <= 0) {
                console.warn("【自动开箱/钓鱼】当前体力为 0，暂停开箱，等待恢复...");
                window.isForgePending = false; // 释放锁，允许下一次心跳重新检测
                return;
            }
            
            // 动态决定本次开箱数量：如果有 3 点体力，就只开 3 个，最多开 1 个
            var targetCount = batchCount || 1;
            
            // 🛡️ 3.1.5. 健壮自愈检测：判断当前待定装备区是否有上一次断线、闪退或执行中断残留的装备
            var pendingEquips = (gd.fullInfo && gd.fullInfo.forgeEquips) || [];
            if (pendingEquips.length > 0) {
                console.warn("⚠️【防卡死自愈】检测到待定区有 " + pendingEquips.length + " 件残留装备，正在优先执行智能穿戴/分解结算...");
                
                var toAttachPending = {};
                var toBreakdownPending = [];
                
                for (var i = 0; i < pendingEquips.length; i++) {
                    var eq = pendingEquips[i];
                    var diff = eq.diffCombatPower || 0;
                    if (diff > 0) {
                        var slot = eq.slot;
                        if (!toAttachPending[slot] || toAttachPending[slot].diffCombatPower < diff) {
                            if (toAttachPending[slot]) {
                                toBreakdownPending.push(toAttachPending[slot].eid);
                            }
                            toAttachPending[slot] = eq;
                        } else {
                            toBreakdownPending.push(eq.eid);
                        }
                    } else {
                        toBreakdownPending.push(eq.eid);
                    }
                }
                
                var preTasks = [];
                Object.keys(toAttachPending).forEach(function(slot) {
                    var eq = toAttachPending[slot];
                    preTasks.push(function(next) {
                        if (!window.isBatchForgeActive) return next();
                        console.log("[自愈穿戴] 穿戴部位 " + slot + " (战力+" + eq.diffCombatPower + ")...");
                        gs.send(function() { next(); }, "attachEquip", { breakdown: 1, equipId: eq.eid });
                    });
                });
                
                if (toBreakdownPending.length > 0) {
                    preTasks.push(function(next) {
                        if (!window.isBatchForgeActive) return next();
                        console.log("[自愈分解] 清空 " + toBreakdownPending.length + " 件残留装备...");
                        gs.send(function() { next(); }, "breakdown", { equipIds: toBreakdownPending });
                    });
                }
                
                var preTaskIndex = 0;
                function runNextPreTask() {
                    if (!window.isBatchForgeActive) {
                        window.isForgePending = false;
                        return;
                    }
                    if (preTaskIndex >= preTasks.length) {
                        // 清理完成，释放锁，并在 400ms 后重新拉起正式开箱
                        window.isForgePending = false;
                        window.batchForgeTimer = setTimeout(function() {
                            window.batchSmartForge(window.lastForgeCount);
                        }, 400);
                        return;
                    }
                    var task = preTasks[preTaskIndex++];
                    task(runNextPreTask);
                }
                
                runNextPreTask();
                return; // 拦截本次开箱，等清理干净后再开！
            }
            var count = Math.min(currentStamina, targetCount);
            window.lastForgeCount = targetCount;
            
            console.log("【自动开箱/钓鱼】当前体力: " + currentStamina + "，正在开启 " + count + " 次/个...");
            
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
                
                // 3.2 穿戴比身上更好的装备
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
                
                // 3.3 批量分解剩下的所有垃圾装备
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
