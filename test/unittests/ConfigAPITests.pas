﻿(*

    Daraja HTTP Framework
    Copyright (C) Michael Justin

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


    You can be released from the requirements of the license by purchasing
    a commercial license. Buying such a license is mandatory as soon as you
    develop commercial activities involving the Daraja framework without
    disclosing the source code of your own applications. These activities
    include: offering paid services to customers as an ASP, shipping Daraja
    with a closed source product.

*)

unit ConfigAPITests;

interface

{$I IdCompilerDefines.inc}

uses
  HTTPTestCase,
  {$IFDEF FPC}fpcunit,testregistry{$ELSE}TestFramework{$ENDIF};

type
  { TAPIConfigTests }

  TAPIConfigTests = class(THTTPTestCase)
  published
    procedure ConfigOneContext;

    procedure AddContextToServer;

    // Multiple contexts may have the same context path and they are
    // called in order until one handles the request.
    procedure AddTwoContextWithSameName;

    procedure ConfigTwoContexts;

    // context
    procedure StopContext;
    procedure StopStartContext;

    //
    procedure ConfigAbsolutePath;

    // exceptions
    procedure TestExceptionInInitStopsComponent;
    procedure TestExceptionInServiceReturns500;

    // context match
    procedure TestNoMatchingContextReturns404;

    // default handler
    procedure TestDefaultHandler;
    procedure TestDefaultHandlerInContext;

    // web component tests
    procedure TestNoMethodReturns405;

    procedure TestPOSTMethodResponse;

    // Web Component init parameter
    procedure TestTdjWebComponentHolder_SetInitParameter;

    procedure TestContextConfig;

    procedure TestConfigGetContextLog;

    // Test character encoding (UTF-8)
    procedure TestCharSet;

    procedure TestContextWithConnectorName;

    procedure TestIPv6ConnectionToLoopback;

    procedure TestAddConnector;
    procedure TestThreadPool;

    procedure TestWrapper;
    procedure TestWrapperWithContexts;
    procedure TestWrapperWithContextsSimple;

    procedure TestBindErrorRaisesException;

    // test overriding the TdjWebComponent.OnGetLastModified method
    // (since 1.2.10)
    procedure TestCachedGetRequest;

  end;

implementation

uses
  djWebAppContext, djInterfaces, djWebComponent, djWebComponentHolder,
  djWebComponentContextHandler, djServer, djDefaultHandler, djStatisticsHandler,
  djHTTPConnector, djContextHandlerCollection, djHandlerList, djTypes,
  IdServerInterceptLogFile, IdSchedulerOfThreadPool, IdGlobal, IdException,
  SysUtils, Classes, djAbstractHandler, djServerContext;

type
  EUnitTestException = class(Exception);

{ TAPIConfigTests }

// this web component returns '' as HTTP GET response ------------------------

type
  TExamplePage = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse); override;
  end;

{ TExamplePage }

procedure TExamplePage.OnGet(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'example';
end;

procedure TAPIConfigTests.ConfigAbsolutePath;
var
  Server: TdjServer;
  Holder: TdjWebComponentHolder;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Holder := TdjWebComponentHolder.Create(TExamplePage);

    Context := TdjWebAppContext.Create('web');
    Context.AddWebComponent(Holder, '/hello.html');

    Server.Add(Context);
    Server.Start;

    // Test the correct path
    CheckGETResponseEquals('example', '/web/hello.html');

    // Test non-existent path
    CheckGETResponse404('/web/bar');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestDefaultHandler;
var
  Server: TdjServer;
  HandlerList: IHandlerContainer;
begin
  Server := TdjServer.Create;
  try
    HandlerList := TdjHandlerList.Create;
    HandlerList.AddHandler(TdjDefaultHandler.Create);
    Server.Handler := HandlerList;
    Server.Start;

    CheckGETResponseContains('Daraja Framework');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestDefaultHandlerInContext;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
  HandlerList: IHandlerContainer;
  DefaultHandler: IHandler;
begin
  Server := TdjServer.Create;
  try
    // create the 'test' context
    Context := TdjWebAppContext.Create('test');
    Context.Add(TExamplePage, '/example');
    Server.Add(Context);
    // add a handlerlist with a TdjDefaultHandler
    DefaultHandler := TdjDefaultHandler.Create;
    HandlerList := TdjHandlerList.Create;
    HandlerList.AddHandler(DefaultHandler);
    Server.AddHandler(HandlerList);
    Server.Start;

    CheckGETResponseContains('Daraja Framework');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.AddTwoContextWithSameName;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('foo');
    Context.Add(TExamplePage, '/bar');
    Server.Add(Context);
    Context := TdjWebAppContext.Create('foo');
    Context.Add(TExamplePage, '/bar2');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('example', '/foo/bar');
    CheckGETResponseEquals('example', '/foo/bar2');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.ConfigOneContext;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('foo');
    Context.Add(TExamplePage, '/bar');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('example', '/foo/bar');
    CheckGETResponse404('/foo2/bar');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.AddContextToServer;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('foo');
    Context.Add(TExamplePage, '/bar');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('example', '/foo/bar');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestIPv6ConnectionToLoopback;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Server.AddConnector('::1');
    Context := TdjWebAppContext.Create('example');
    Context.Add(TExamplePage, '/index.html');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('example', 'http://[::1]/example/index.html');

  finally
    Server.Free;
  end;
end;

// TCmpReturnsInitParams -----------------------------------------------------
type
  TCmpReturnsInitParams = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse); override;
  end;

procedure TCmpReturnsInitParams.OnGet(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := GetWebComponentConfig.GetInitParameter('test');
end;

procedure TAPIConfigTests.TestTdjWebComponentHolder_SetInitParameter;
var
  Server: TdjServer;
  Holder: TdjWebComponentHolder;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('context');
    Holder := TdjWebComponentHolder.Create(TCmpReturnsInitParams);
    Holder.SetInitParameter('test', 'success');
    Context.AddWebComponent(Holder, '/*');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('success', '/context/');

  finally
    Server.Free;
  end;
end;

// TestWrapper ---------------------------------------------------------------

type
  THelloHandler = class(TdjAbstractHandler)
  public
    procedure Handle(const Target: string; Context: TdjServerContext;
      Request: TdjRequest; Response: TdjResponse); override;
  end;

{ THelloHandler }

procedure THelloHandler.Handle(const Target: string; Context: TdjServerContext;
  Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'Hello world!';
  Response.ResponseNo := 200;
end;

procedure TAPIConfigTests.TestWrapper;
var
  Server: TdjServer;
  Wrapper: TdjStatisticsHandler;
begin
  Server := TdjServer.Create;
  try
    Wrapper := TdjStatisticsHandler.Create;
    try
      Server.Handler := Wrapper;
      Wrapper.AddHandler(THelloHandler.Create);
      Server.Start;

      CheckGETResponseEquals('Hello world!', '/');

      CheckEquals(1, Wrapper.Responses2xx);

      CheckEquals(0, Wrapper.RequestsActive);
      CheckEquals(1, Wrapper.Requests, 'Requests');

      CheckEquals(0, Wrapper.RequestsDurationTotal, 'RequestsDurationTotal');
      CheckEquals(0, Wrapper.RequestsDurationAve, 'RequestsDurationAve');

      CheckEquals(0, Wrapper.RequestsDurationMin, 'RequestsDurationMin');
      CheckEquals(0, Wrapper.RequestsDurationMax, 'RequestsDurationMax');

      Server.Stop;
    finally
      // Wrapper.Free;
    end;
  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestWrapperWithContexts;
var
  Server: TdjServer;
  Wrapper: TdjStatisticsHandler;
  ContextHandlers: IHandlerContainer;
  ContextHandler: TdjWebComponentContextHandler;
begin
  Server := TdjServer.Create;
  try
    Wrapper := TdjStatisticsHandler.Create;
    try
      Server.Handler := Wrapper;
      ContextHandlers := TdjContextHandlerCollection.Create;
      Wrapper.AddHandler(ContextHandlers);
      // /web1/example1.html
      ContextHandler := TdjWebComponentContextHandler.Create('web1');
      ContextHandlers.AddHandler(ContextHandler);
      ContextHandler.Add(TExamplePage, '/example1.html');
      // /web2/example2.html
      ContextHandler := TdjWebComponentContextHandler.Create('web2');
      ContextHandlers.AddHandler(ContextHandler);
      ContextHandler.Add(TExamplePage, '/example2.html');
      Server.Start;

      // Test the component
      CheckGETResponseEquals('example', '/web1/example1.html');
      CheckGETResponseEquals('example', '/web2/example2.html');

      CheckEquals(2, Wrapper.Responses2xx);
      CheckEquals(2, Wrapper.Requests, 'Requests');

      Server.Stop;
    finally
      // Wrapper.Free;
    end;
  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestWrapperWithContextsSimple;
var
  Server: TdjServer;
  Wrapper: TdjStatisticsHandler;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Wrapper := TdjStatisticsHandler.Create;
    try
      Server.AddHandler(Wrapper);

      // /web1/example1.html
      Context := TdjWebAppContext.Create('web1');
      Context.Add(TExamplePage, '/example1.html');
      Server.Add(Context);

      // /web2/example2.html
      Context := TdjWebAppContext.Create('web2');
      Context.Add(TExamplePage, '/example2.html');
      Server.Add(Context);

      Server.Start;

      // Test the component
      CheckGETResponseEquals('example', '/web1/example1.html');
      CheckGETResponseEquals('example', '/web2/example2.html');

      CheckEquals(2, Wrapper.Responses2xx);
      CheckEquals(2, Wrapper.Requests, 'Requests');

      Server.Stop;
    finally
      // Wrapper.Free;
    end;
  finally
    Server.Free;
  end;
end;

type
  TNoMethodComponent = class(TdjWebComponent)
  end;

procedure TAPIConfigTests.TestBindErrorRaisesException;
var
  Server1: TdjServer;
  Server2: TdjServer;
  Context: TdjWebAppContext;
begin
  Server1 := TdjServer.Create;
  try
    Server1.Start;
    Server2 := TdjServer.Create;
    try
      Context := TdjWebAppContext.Create('get');
      Context.AddWebComponent(TNoMethodComponent, '/hello');
      Server2.Add(Context);

      try
        Server2.Start;
      except
        on E: EIdCouldNotBindSocket do
          CheckEquals('Could not bind socket. Address and port are already in use.', E.Message);
        on E: Exception do
          Fail(E.Message);
      end;

    finally
      Server2.Free;
    end;
  finally
    Server1.Free;
  end;
end;

// this web component raises an exception in the Init method -----------------
type
  TExceptionInInitComponent = class(TdjWebComponent)
  public
    procedure Init(const Config: IWebComponentConfig); override;
  end;

{ TExceptionInInitComponent }

procedure TExceptionInInitComponent.Init(const Config: IWebComponentConfig);
begin
  inherited;

  raise EUnitTestException.Create('error');
end;

procedure TAPIConfigTests.TestExceptionInInitStopsComponent;
var
  Server: TdjServer;
  Holder: TdjWebComponentHolder;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Holder := TdjWebComponentHolder.Create(TExceptionInInitComponent);
    Context := TdjWebAppContext.Create('ctx');
    Context.AddWebComponent(Holder, '/exception');
    Server.Add(Context);
    Server.Start;

    // Test the component
    CheckGETResponse404('/ctx/exception');

  finally
    Server.Free;
  end;
end;

// test exception in service -------------------------------------------------
type
  TExceptionComponent = class(TdjWebComponent)
  public
    procedure Service(Context: TdjServerContext; Request: TdjRequest;
      Response: TdjResponse); override;
  end;

{ TExceptionComponent }

procedure TExceptionComponent.Service(Context: TdjServerContext;
  Request: TdjRequest; Response: TdjResponse);
begin
  raise EUnitTestException.Create('test');
end;

procedure TAPIConfigTests.TestExceptionInServiceReturns500;
var
  Server: TdjServer;
  Holder: TdjWebComponentHolder;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Holder := TdjWebComponentHolder.Create(TExceptionComponent);
    Context := TdjWebAppContext.Create('ctx');
    Context.AddWebComponent(Holder, '/exception');
    Server.Add(Context);
    Server.Start;

    CheckGETResponse500('/ctx/exception');

  finally
    Server.Free;
  end;
end;

// ---
type
  TGetComponent = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse);  override;
  end;

{ TGetComponent }

procedure TGetComponent.OnGet(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'Hello';
end;

// ---
type
  TCachedGetComponent = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse);  override;
    function OnGetLastModified(Request: TdjRequest): TDateTime; override;
  end;

{ TCachedGetComponent }

procedure TCachedGetComponent.OnGet(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'CachedGET';
end;

function TCachedGetComponent.OnGetLastModified(Request: TdjRequest): TDateTime;
begin
  Result := Now;
end;

procedure TAPIConfigTests.TestNoMatchingContextReturns404;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('example');
    Context.AddWebComponent(TExamplePage, '*.html');
    Server.Add(Context);
    Server.Start;

    CheckGETResponse404('/example2/a.html');
    CheckGETResponse404('/Example/b.html');
    CheckGETResponse200('/example/c.html');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestNoMethodReturns405;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('get');
    Context.AddWebComponent(TNoMethodComponent, '/hello');
    Server.Add(Context);
    Server.Start;

    CheckGETResponse405('/get/hello')

  finally
    Server.Free;
  end;
end;

// this web component declares a POST handler --------------------------------

type
  TPostComponent = class(TdjWebComponent)
  public
    procedure OnPost(Request: TdjRequest; Response: TdjResponse); override;
  end;

{ TPostComponent }

procedure TPostComponent.OnPost(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'thank you for POSTing';
end;

procedure TAPIConfigTests.TestPOSTMethodResponse;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('example');
    Context.AddWebComponent(TPostComponent, '/index.html');
    Server.Add(Context);
    Server.Start;

    CheckPOSTResponseEquals('thank you for POSTing', '/example/index.html');
    CheckGETResponse405('/example/index.html');
  finally
    Server.Free;
  end;
end;

// Service method is overriden -----------------------------------------------

type
  THello2WebComponent = class(TdjWebComponent)
  public
    procedure Service(Context: TdjServerContext; Request: TdjRequest;
      Response: TdjResponse); override;
  end;

{ THello2WebComponent }

procedure THello2WebComponent.Service(Context: TdjServerContext;
  Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := 'Hello universe!';
end;

procedure TAPIConfigTests.ConfigTwoContexts;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    // create and register component 1
    Context := TdjWebAppContext.Create('foo');
    Context.AddWebComponent(TExamplePage, '/bar');
    Server.Add(Context);
    // create and register component 2
    Context := TdjWebAppContext.Create('foo2');
    Context.AddWebComponent(THello2WebComponent, '/bar2');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('example', '/foo/bar');
    CheckGETResponseEquals('Hello universe!', '/foo2/bar2');
    CheckGETResponse404('/foo2/bar');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.StopContext;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('');
    Server.Add(Context);
    Server.Start;
    Context.Stop;
  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.StopStartContext;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('');
    Server.Add(Context);
    Server.Start;
    Context.Stop;
    Context.Start;
  finally
    Server.Free;
  end;
end;

// this web component writes to the context log ----------
type
  TLogComponent = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse); override;
  end;

{ TLogComponent }

procedure TLogComponent.OnGet(Request: TdjRequest; Response: TdjResponse);
var
  Value: string;
begin
  Config.GetContext.Log('This is a log message sent from TLogComponent.OnGet ...');

  Value := Config.GetContext.GetInitParameter('key');

  Config.GetContext.Log('Value=' + Value);

  Response.ContentText := 'TLogComponent';
end;

procedure TAPIConfigTests.TestConfigGetContextLog;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('log');
    Context.SetInitParameter('key', 'Context init parameter value');
    Context.AddWebComponent(TLogComponent, '/hello');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseContains('TLogComponent', '/log/hello')

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestAddConnector;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
  Connector: TdjHTTPConnector;
  Intercept: TIdServerInterceptLogFile;
begin
  Intercept := TIdServerInterceptLogFile.Create;
  try
    Server := TdjServer.Create;
    try
      // add a configured connector
      Connector := TdjHTTPConnector.Create(Server.Handler);
      // TODO DOC not TdjHTTPConnector.Create(Server)!
      Connector.Host := '127.0.0.1';
      Connector.Port := 80;
      // new property "HTTPServer" in 1.5
      // here used to set a file based logger for the HTTP server
      Connector.HTTPServer.Intercept := Intercept;
      Intercept.Filename := 'httpIntercept.log';
      Server.AddConnector(Connector);
      Context := TdjWebAppContext.Create('get');
      Context.Add(TGetComponent, '/hello');
      Server.Add(Context);
      Server.Start;

      CheckGETResponseEquals('Hello', '/get/hello');

    finally
      Server.Free;
    end;
  finally
    Intercept.Free
  end;
end;

procedure TAPIConfigTests.TestThreadPool;
var
  SchedulerOfThreadPool: TIdSchedulerOfThreadPool;
  Server: TdjServer;
  Context: TdjWebAppContext;
  Connector: TdjHTTPConnector;
begin
  Server := TdjServer.Create;
  try
    // add a configured connector
    Connector := TdjHTTPConnector.Create(Server.Handler);
    // TODO DOC not TdjHTTPConnector.Create(Server)!
    Connector.Host := '127.0.0.1';
    Connector.Port := 80;
    SchedulerOfThreadPool := TIdSchedulerOfThreadPool.Create(Connector.HTTPServer);
    SchedulerOfThreadPool.PoolSize := 20;
    // set thread pool scheduler
    Connector.HTTPServer.Scheduler := SchedulerOfThreadPool;
    Server.AddConnector(Connector);
    Context := TdjWebAppContext.Create('get');
    Context.Add(TGetComponent, '/hello');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('Hello', '/get/hello');

    Server.Stop;
  finally
    Server.Free;
  end;
end;

// test context init parameter

type
  TContextInitParamComponent = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse); override;
  end;

{ TContextInitParamComponent }

procedure TContextInitParamComponent.OnGet(Request: TdjRequest; Response: TdjResponse);
var
  InitParamValue: string;
begin
  InitParamValue := Config.GetContext.GetInitParameter('a');

  WriteLn('>>>> a=' + InitParamValue);
  Response.ContentText := InitParamValue;
end;

procedure TAPIConfigTests.TestContextConfig;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('example');
    Context.Add(TContextInitParamComponent, '/index.html');
    Context.SetInitParameter('a', 'myValue');
    Server.Add(Context);
    Server.Start;

    CheckGETResponseEquals('myValue', '/example/index.html');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestContextWithConnectorName;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
  ContextPublic: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Server.AddConnector('127.0.0.1', 8181);
    Server.AddConnector('127.0.0.1', 80);
    Server.AddConnector('127.0.0.1', 8282); // unused, just to see the order
    // configure for context on standard port
    ContextPublic := TdjWebAppContext.Create('public');
    ContextPublic.Add(TExamplePage, '/hello');
    // configure for context on special port
    Context := TdjWebAppContext.Create('get');
    Context.Add(TExamplePage, '/hello');
    Context.ConnectorNames.Add('127.0.0.1:8181');
    Server.Add(ContextPublic);
    Server.Add(Context);
    Server.Start;

    // this does not work as the connector listens on port 8181
    CheckGETResponse404('/get/hello');

    // this works (special port)
    CheckGETResponseEquals('example', 'http://127.0.0.1:8181/get/hello');

    // this works (default port)
    CheckGETResponseEquals('example', 'http://' + DEFAULT_BINDING_IP + ':' +
      IntToStr(DEFAULT_BINDING_PORT) + '/public/hello');

  finally
    Server.Free;
  end;
end;

// ---------------------------------------------------------------------------

{ TCharSetComponent }

type
  TCharSetComponent = class(TdjWebComponent)
  public
    procedure OnGet(Request: TdjRequest; Response: TdjResponse);
      override;
  end;

procedure TCharSetComponent.OnGet(Request: TdjRequest; Response: TdjResponse);
begin
  Response.ContentText := '中文';
  Response.ContentType := 'text/plain';
  Response.CharSet := 'utf-8';
end;

procedure TAPIConfigTests.TestCharSet;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('get');
    Context.Add(TCharSetComponent, '/hello');
    Server.Add(Context);
    Server.Start;

    {$IFDEF STRING_IS_ANSI}
    DestEncoding := IndyTextEncoding_UTF8; // TODO document
    {$ENDIF}

    CheckGETResponseEquals('中文', '/get/hello');

  finally
    Server.Free;
  end;
end;

procedure TAPIConfigTests.TestCachedGetRequest;
var
  Server: TdjServer;
  Context: TdjWebAppContext;
begin
  Server := TdjServer.Create;
  try
    Context := TdjWebAppContext.Create('cached');
    Context.AddWebComponent(TCachedGetComponent, '*.html');
    Server.Add(Context);
    Server.Start;

    // set "If-Modified-Since" header to yesterday to enforce a fresh response
    CheckCachedGETResponseEquals(Date - 1, 'CachedGET', '/cached/index.html');

    // set "If-Modified-Since" header to Now to get "304 resource not modified"
    CheckCachedGETResponseIs304(Now, '/cached/index.html');

  finally
    Server.Free;
  end;
end;

end.

