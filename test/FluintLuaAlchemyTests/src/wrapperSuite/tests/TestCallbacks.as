package wrapperSuite.tests
{
  import luaAlchemy.lua_wrapper;

  import flash.utils.ByteArray;
  import net.digitalprimates.fluint.tests.TestCase;

  public class TestCallbacks extends CommonTestCase
  {
    public function testLuaAddEventListener():void
    {
      var myHelper:TestWrapperHelper = new TestWrapperHelper();
      lua_wrapper.setGlobal(luaState, "testHelper", myHelper);

      var script:String = ( <![CDATA[
       as3.call(testHelper,
                "addEventListener",
                "TestWrapperHelperEvent",
                function () as3.call(testHelper, "setNameAge", "Timmy", 99) end)
      ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      myHelper.sendEvent();

      assertTrue(stack[0]);
      assertEquals(1, stack.length);

      assertEquals("Name: Timmy age: 99", myHelper.nameAge);
    }

    public function testCallLuaFunctionGetNoop():void
    {
      var script:String = ( <![CDATA[
       return function() end
      ]]> ).toString();

      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      trace(stack.toString());
      assertTrue(stack[0]);
      assertTrue(stack[1] is Function);
      assertEquals(2, stack.length);
    }

    public function testCallLuaFunctionCallNoop():void
    {
      var script:String = ( <![CDATA[
       return function() end
      ]]> ).toString();

      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      trace(stack.toString());

      assertTrue(stack[0]);
      assertTrue(stack[1] is Function);
      assertEquals(2, stack.length);

      var func:Function = stack[1] as Function;

      var ret:* = func();
      assertEquals(null, ret);
    }

    public function testLuaCallbackCleanupWithListener():void
    {
      var myHelper:TestWrapperHelper = new TestWrapperHelper();
      myHelper.count = 0;

      var script:String = ( <![CDATA[
       as3.call(
           testHelper,
           "addEventListener",
           "TestWrapperIncrementEvent",
           function()
             as3.set(testHelper, "count", as3.get(testHelper, "count") + 1)
           end)
      ]]> ).toString();

      var stack:Array;
      var expected:int;
      for (expected = 1; expected <= 10; expected++)
      {
        lua_wrapper.luaClose(luaState);
        luaState = lua_wrapper.luaInitilizeState();
        lua_wrapper.setGlobal(luaState, "testHelper", myHelper);

        stack = lua_wrapper.luaDoString(luaState, script);

        myHelper.sendIncrementEvent();

        assertEquals(1, stack.length);
        assertTrue(stack[0]);
        assertEquals(expected, myHelper.count);
      }
    }

    // TODO test garbage collection cleanup (like the movebox demo)

    public function testCallLuaFunctionWithParametersNilReturn():void
    {
      var myHelper:TestWrapperHelper = new TestWrapperHelper();
      lua_wrapper.setGlobal(luaState, "testHelper", myHelper);

      var script:String = ( <![CDATA[
       return function (name, age) as3.call(testHelper, "setNameAge", name, age) end
      ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      assertTrue(stack[0]);
      assertTrue(stack[1] is Function);
      assertEquals(2, stack.length);

      var func:Function = stack[1] as Function;
      var ret:* = func("Neo", 40);
      assertEquals(null, ret);

      assertEquals("Name: Neo age: 40", myHelper.nameAge);
    }

    public function testCallLuaFunctionWithSingleReturn():void
    {
      var myHelper:TestWrapperHelper = new TestWrapperHelper();
      lua_wrapper.setGlobal(luaState, "testHelper", myHelper);

      var script:String = ( <![CDATA[
       return function ()
            return 1 + 12
        end
      ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      assertTrue(stack[0]);
      assertTrue(stack[1] is Function);
      assertEquals(2, stack.length);

      var func:Function = stack[1] as Function;
      var ret:* = func();
      assertTrue(ret is Number);
      assertEquals(13, ret);
    }

    public function testCallLuaFunctionWithMultiReturn():void
    {
      var myHelper:TestWrapperHelper = new TestWrapperHelper();
      lua_wrapper.setGlobal(luaState, "testHelper", myHelper);

      var script:String = ( <![CDATA[
        return function ()
          return 1 + 12, "hello there"
        end
      ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      assertTrue(stack[0]);
      assertTrue(stack[1] is Function);
      assertEquals(2, stack.length);

      var func:Function = stack[1] as Function;
      var ret:* = func();

      assertTrue(ret is Array);
      assertEquals(2, ret.length);
      assertEquals(13, ret[0]);
      assertEquals("hello there", ret[1]);
    }


    public function testCreateCallbackInLua():void
    {
      var script:String = ( <![CDATA[
        as3.new("Function", function() end) -- TODO: Does this make sense?
        ]]> ).toString();

      var stack:Array = lua_wrapper.luaDoString(luaState, script);
      assertTrue(stack[0]);
      assertEquals(1, stack.length);
    }

    public function testCreateAndCallObject():void
    {
      var script:String = ( <![CDATA[
        local create_as_object = function()
           local obj = as3.new("Object")
           as3.set(
               obj,
               "addThirteen",
               function(n)
                 return n + 13
               end
             )
           return obj
        end
        local as_object = create_as_object()
        local result = as3.call(as_object, "addThirteen", 5)
        assert(type(result) == "number", "wrong result: "..tostring(result))
        result = result + 2
        return result
        ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      trace(stack);

      assertTrue(stack[0]);
      assertEquals(20, stack[1]);
      assertEquals(2, stack.length);
    }

    public function testCreateAndCallObjectErrorNonstring():void
    {
      var script:String = ( <![CDATA[
        local create_as_object = function()
           local obj = as3.new("Object")
           as3.set(
               obj,
               "error",
               function(n)
                 error({})
               end
             )
           return obj
        end
        local as_object = create_as_object()
        as3.call(as_object, "error")
        return "error is ignored"
        ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      trace(stack);

      assertTrue(stack[0]);
      assertEquals("error is ignored", stack[1]);
      assertEquals(2, stack.length);
    }

    public function testCreateAndCallObjectErrorString():void
    {
      var script:String = ( <![CDATA[
        local create_as_object = function()
           local obj = as3.new("Object")
           as3.set(
               obj,
               "error",
               function(n)
                 as3.trace("about to trigger error")
                 error("Boo!")
               end
             )
           return obj
        end
        local as_object = create_as_object()
        as3.trace("about to call method")
        as3.call(as_object, "error")
        return "error is ignored"
        ]]> ).toString();
      var stack:Array = lua_wrapper.luaDoString(luaState, script);

      trace(stack);

      assertTrue(stack[0]);
      assertEquals("error is ignored", stack[1]);
      assertEquals(2, stack.length);
    }
  }
}
