public virtual class TriggerHandler {
  /***********************
   * Static resources for general use on controlled execution
   ***********************/
  private static Map<String, LoopCount> loopCountMap; // map of handler name, times run() was invoked

  private static Set<String> bypassedHandlers; // bypass handles set for bypassed execution

  private static Boolean isGlobalBypass; // general global bypass to skip all executions
  private static Boolean showLimits; // control if limits will be displayed during execution

  /***********************
   * resources for general use on controlled execution
   ***********************/
  @TestVisible
  private TriggerContext context; // the current context of the trigger, can be override in tests
  @TestVisible
  private Boolean isTriggerExecuting; // the current context of the trigger, can be override in tests

  private String handlerName; // Handler name to be used on bypass check

  // static initialization
  static {
    loopCountMap = new Map<String, LoopCount>();
    bypassedHandlers = new Set<String>();
    isGlobalBypass = false;
    showLimits = false;
  }

  // constructor
  /* public TriggerHandler() {
        this.setTriggerContext();
    } */
  public TriggerHandler(String handlerName) {
    this.handlerName = handlerName;
    this.setTriggerContext();
  }

  public TriggerHandler(Type handlerType) {
    this.handlerName = handlerType.getName();
    this.setTriggerContext();
  }

  /***************************************
   * public instance methods
   ***************************************/

  // main method that will be called during execution
  public void run() {
    if (!validateRun()) {
      return;
    }

    addToLoopCount();

    // dispatch to the correct handler method
    switch on this.context {
      when BEFORE_INSERT {
        this.beforeInsert();
      }
      when BEFORE_UPDATE {
        this.beforeUpdate();
      }
      when BEFORE_DELETE {
        this.beforeDelete();
      }
      when AFTER_INSERT {
        this.afterInsert();
      }
      when AFTER_UPDATE {
        this.afterUpdate();
      }
      when AFTER_DELETE {
        this.afterDelete();
      }
      when AFTER_UNDELETE {
        this.afterUndelete();
      }
    }

    if (showLimits) {
      System.debug(
        LoggingLevel.DEBUG,
        String.format(
          '{0} on {1} ({2}/{3})',
          new List<String>{
            this.context + '',
            getHandlerName(),
            Limits.getQueries() + '',
            Limits.getLimitQueries() + ''
          }
        )
      );
    }
  }

  public void setMaxLoopCount(Integer max) {
    String handlerName = getHandlerName();
    if (!TriggerHandler.loopCountMap.containsKey(handlerName)) {
      TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
    } else {
      TriggerHandler.loopCountMap.get(handlerName).setMax(max);
    }
  }

  public void clearMaxLoopCount() {
    this.setMaxLoopCount(-1);
  }

  /***************************************
   * public static methods
   ***************************************/

  public static void bypass(String handlerName) {
    TriggerHandler.bypassedHandlers.add(handlerName);
  }

  public static void bypass(List<String> handlersNames) {
    TriggerHandler.bypassedHandlers.addAll(handlersNames);
  }

  public static void bypass(Type handlerType) {
    TriggerHandler.bypass(handlerType.getName());
  }

  public static void globalBypass() {
    TriggerHandler.isGlobalBypass = true;
  }

  public static void clearBypass(String handlerName) {
    TriggerHandler.bypassedHandlers.remove(handlerName);
  }

  public static void clearBypass(Type handlerType) {
    clearBypass(handlerType.getName());
  }

  public static void clearBypass(List<String> handlersNames) {
    TriggerHandler.bypassedHandlers.removeAll(handlersNames);
  }

  public static void clearAllBypasses() {
    TriggerHandler.bypassedHandlers.clear();
  }

  public static void clearGlobalBypass() {
    TriggerHandler.isGlobalBypass = false;
  }

  public static void clearAllBypassesGlobal() {
    clearAllBypasses();
    clearGlobalBypass();
  }

  public static Boolean isBypassed(String handlerName) {
    return (TriggerHandler.isGlobalBypass ||
    TriggerHandler.bypassedHandlers.contains(handlerName));
  }

  public static Boolean isBypassed(Type handlerType) {
    return isBypassed(handlerType.getName());
  }

  public static void showLimits() {
    showLimits(true);
  }

  public static void showLimits(Boolean enabled) {
    showLimits = enabled;
  }

  public static Integer getLoopCount(String handlerName) {
    if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
      return TriggerHandler.loopCountMap.get(handlerName).getCount();
    }
    return 0;
  }

  /***************************************
   * private instance methods
   ***************************************/

  private Boolean isBypassed() {
    return isBypassed(this.handlerName);
  }

  @TestVisible
  private void setTriggerContext() {
    this.setTriggerContext(null, false);
  }

  @TestVisible
  private void setTriggerContext(String ctx, Boolean testMode) {
    if (!Trigger.isExecuting && !testMode) {
      this.isTriggerExecuting = false;
      return;
    } else {
      this.isTriggerExecuting = true;
    }

    if (
      (Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
      (ctx != null &&
      ctx == 'before insert')
    ) {
      this.context = TriggerContext.BEFORE_INSERT;
    } else if (
      (Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
      (ctx != null &&
      ctx == 'before update')
    ) {
      this.context = TriggerContext.BEFORE_UPDATE;
    } else if (
      (Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
      (ctx != null &&
      ctx == 'before delete')
    ) {
      this.context = TriggerContext.BEFORE_DELETE;
    } else if (
      (Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
      (ctx != null &&
      ctx == 'after insert')
    ) {
      this.context = TriggerContext.AFTER_INSERT;
    } else if (
      (Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
      (ctx != null &&
      ctx == 'after update')
    ) {
      this.context = TriggerContext.AFTER_UPDATE;
    } else if (
      (Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
      (ctx != null &&
      ctx == 'after delete')
    ) {
      this.context = TriggerContext.AFTER_DELETE;
    } else if (
      (Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
      (ctx != null &&
      ctx == 'after undelete')
    ) {
      this.context = TriggerContext.AFTER_UNDELETE;
    }
  }

  // increment the loop count
  @TestVisible
  private void addToLoopCount() {
    String handlerName = getHandlerName();
    if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
      Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName)
        .increment();
      if (exceeded) {
        Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
        throw new TriggerHandlerException(
          'Maximum loop count of ' +
            String.valueOf(max) +
            ' reached in ' +
            handlerName
        );
      }
    }
  }

  // make sure this trigger should continue to run
  @TestVisible
  private Boolean validateRun() {
    if (!this.isTriggerExecuting || this.context == null) {
      throw new TriggerHandlerException(
        'Trigger handler called outside of Trigger execution'
      );
    }
    if (isBypassed()) {
      return false;
    }
    return true;
  }

  @TestVisible
  private String getHandlerName() {
    if (String.isBlank(this.handlerName)) {
      this.handlerName = this.toString().substringBefore(':');
    }
    return this.handlerName;
  }

  /***************************************
   * context methods
   ***************************************/

  // context-specific methods for override
  @TestVisible
  protected virtual void beforeInsert() {
  }
  @TestVisible
  protected virtual void beforeUpdate() {
  }
  @TestVisible
  protected virtual void beforeDelete() {
  }
  @TestVisible
  protected virtual void afterInsert() {
  }
  @TestVisible
  protected virtual void afterUpdate() {
  }
  @TestVisible
  protected virtual void afterDelete() {
  }
  @TestVisible
  protected virtual void afterUndelete() {
  }

  /***************************************
   * inner classes
   ***************************************/

  // inner class for managing the loop count per handler
  @TestVisible
  private class LoopCount {
    private Integer max;
    private Integer count;

    public LoopCount() {
      this.max = 5;
      this.count = 0;
    }

    public LoopCount(Integer max) {
      this.max = max;
      this.count = 0;
    }

    public Boolean increment() {
      this.count++;
      return this.exceeded();
    }

    public Boolean exceeded() {
      if (this.max < 0)
        return false;
      if (this.count > this.max) {
        return true;
      }
      return false;
    }

    public Integer getMax() {
      return this.max;
    }

    public Integer getCount() {
      return this.count;
    }

    public void setMax(Integer max) {
      this.max = max;
    }
  }

  // possible trigger contexts
  @TestVisible
  private enum TriggerContext {
    BEFORE_INSERT,
    BEFORE_UPDATE,
    BEFORE_DELETE,
    AFTER_INSERT,
    AFTER_UPDATE,
    AFTER_DELETE,
    AFTER_UNDELETE
  }

  // exception class
  public class TriggerHandlerException extends Exception {
  }
}
