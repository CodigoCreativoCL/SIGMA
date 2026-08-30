using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http.Hosting;


namespace Controllers
{
    public class WebApiCustomMessageHandler : DelegatingHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(
          HttpRequestMessage request, CancellationToken cancellationToken)
        {

            HttpResponseMessage response = await base.SendAsync(request, cancellationToken);

            /**
            * Code   => 206
            * Status => HttpStatusCode.PartialContent
            */
            if (response.StatusCode == HttpStatusCode.PartialContent)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 206. PartialContent indicates that the response is a partial response as requested by a GET request that includes a byte range.");

                return errorResponse;
            }

            /**
            * Code   => 402
            * Status => HttpStatusCode.PaymentRequired
            */
            if (response.StatusCode == HttpStatusCode.PaymentRequired)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 402. PaymentRequired is reserved for future use.");

                return errorResponse;
            }

            /**
            * Code   => 412
            * Status => HttpStatusCode.PreconditionFailed
            */
            if (response.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 412. PreconditionFailed indicates that a condition set for this request failed, and the request cannot be carried out. Conditions are set with conditional request headers like If-Match, If-None-Match, or If-Unmodified-Since.");

                return errorResponse;
            }

            /**
            * Code   => 407
            * Status => HttpStatusCode.ProxyAuthenticationRequired
            */
            if (response.StatusCode == HttpStatusCode.ProxyAuthenticationRequired)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 407. ProxyAuthenticationRequired indicates that the requested proxy requires authentication. The Proxy-authenticate header contains the details of how to perform the authentication.");

                return errorResponse;
            }

            /**
            * Code   => 302
            * Status => HttpStatusCode.Redirect
            */
            if (response.StatusCode == HttpStatusCode.Redirect)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 302. Redirect indicates that the requested information is located at the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. When the original request method was POST, the redirected request will use the GET method. Redirect is a synonym for Found.");

                return errorResponse;
            }

            /**
            * Code   => 307
            * Status => HttpStatusCode.RedirectKeepVerb
            */
            if (response.StatusCode == HttpStatusCode.RedirectKeepVerb)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 307. RedirectKeepVerb indicates that the request information is located at the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. When the original request method was POST, the redirected request will also use the POST method. RedirectKeepVerb is a synonym for TemporaryRedirect.");

                return errorResponse;
            }

            /**
            * Code   => 303
            * Status => HttpStatusCode.RedirectMethod
            */
            if (response.StatusCode == HttpStatusCode.RedirectMethod)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 303. RedirectMethod automatically redirects the client to the URI specified in the Location header as the result of a POST. The request to the resource specified by the Location header will be made with a GET. RedirectMethod is a synonym for SeeOther.");

                return errorResponse;
            }

            /**
            * Code   => 416
            * Status => HttpStatusCode.RequestedRangeNotSatisfiable
            */
            if (response.StatusCode == HttpStatusCode.RequestedRangeNotSatisfiable)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 416. RequestedRangeNotSatisfiable indicates that the range of data requested from the resource cannot be returned, either because the beginning of the range is before the beginning of the resource, or the end of the range is after the end of the resource.");

                return errorResponse;
            }

            /**
            * Code   => 413
            * Status => HttpStatusCode.RequestEntityTooLarge
            */
            if (response.StatusCode == HttpStatusCode.RequestEntityTooLarge)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 413. RequestEntityTooLarge indicates that the request is too large for the server to process.");

                return errorResponse;
            }

            /**
            * Code   => 408
            * Status => HttpStatusCode.RequestTimeout
            */
            if (response.StatusCode == HttpStatusCode.RequestTimeout)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 408. RequestTimeout indicates that the client did not send a request within the time the server was expecting the request.");

                return errorResponse;
            }

            /**
            * Code   => 414
            * Status => HttpStatusCode.RequestUriTooLong
            */
            if (response.StatusCode == HttpStatusCode.RequestUriTooLong)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 414. RequestUriTooLong indicates that the URI is too long.");

                return errorResponse;
            }

            /**
            * Code   => 205
            * Status => HttpStatusCode.ResetContent
            */
            if (response.StatusCode == HttpStatusCode.ResetContent)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 205. ResetContent indicates that the client should reset (not reload) the current resource.");

                return errorResponse;
            }

            /**
            * Code   => 303
            * Status => HttpStatusCode.SeeOther
            */
            if (response.StatusCode == HttpStatusCode.SeeOther)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 303. SeeOther automatically redirects the client to the URI specified in the Location header as the result of a POST. The request to the resource specified by the Location header will be made with a GET. SeeOther is a synonym for RedirectMethod");

                return errorResponse;
            }

            /**
            * Code   => 503
            * Status => HttpStatusCode.ServiceUnavailable
            */
            if (response.StatusCode == HttpStatusCode.ServiceUnavailable)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 503. ServiceUnavailable indicates that the server is temporarily unavailable, usually due to high load or maintenance.");

                return errorResponse;
            }

            /**
            * Code   => 101
            * Status => HttpStatusCode.SwitchingProtocols
            */
            if (response.StatusCode == HttpStatusCode.SwitchingProtocols)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 101. SwitchingProtocols indicates that the protocol version or protocol is being changed.");

                return errorResponse;
            }

            /**
            * Code   => 307
            * Status => HttpStatusCode.TemporaryRedirect
            */
            if (response.StatusCode == HttpStatusCode.TemporaryRedirect)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 307. TemporaryRedirect indicates that the request information is located at the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. When the original request method was POST, the redirected request will also use the POST method. TemporaryRedirect is a synonym for RedirectKeepVerb.");

                return errorResponse;
            }

            /**
            * Code   => 401
            * Status => HttpStatusCode.Unauthorized
            */
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 401. Unauthorized indicates that the requested resource requires authentication. The WWW-Authenticate header contains the details of how to perform the authentication.");

                return errorResponse;
            }

            /**
            * Code   => 415
            * Status => HttpStatusCode.UnsupportedMediaType
            */
            if (response.StatusCode == HttpStatusCode.UnsupportedMediaType)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 415. UnsupportedMediaType indicates that the request is an unsupported type.");

                return errorResponse;
            }

            /**
            * Code   => 306
            * Status => HttpStatusCode.Unused
            */
            if (response.StatusCode == HttpStatusCode.Unused)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 306. Unused is a proposed extension to the HTTP/1.1 specification that is not fully specified.");

                return errorResponse;
            }

            /**
            * Code   => 426
            * Status => HttpStatusCode.UpgradeRequired
            */
            if (response.StatusCode == HttpStatusCode.UpgradeRequired)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 426. UpgradeRequired indicates that the client should switch to a different protocol such as TLS/1.0.");

                return errorResponse;
            }

            /**
            * Code   => 305
            * Status => HttpStatusCode.UseProxy
            */
            if (response.StatusCode == HttpStatusCode.UseProxy)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 305. UseProxy indicates that the request should use the proxy server at the URI specified in the Location header.");

                return errorResponse;
            }

            /**
            * Code   => 202
            * Status => HttpStatusCode.Accepted
            */
            if (response.StatusCode == HttpStatusCode.Accepted)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 202. Accepted indicates that the request has been accepted for further processing.");

                return errorResponse;
            }

            /**
            * Code   => 300
            * Status => HttpStatusCode.Ambiguous
            */
            if (response.StatusCode == HttpStatusCode.Ambiguous)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 300. Ambiguous indicates that the requested information has multiple representations. The default action is to treat this status as a redirect and follow the contents of the Location header associated with this response. Ambiguous is a synonym for MultipleChoices.");

                return errorResponse;
            }

            /**
            * Code   => 502
            * Status => HttpStatusCode.BadGateway
            */
            if (response.StatusCode == HttpStatusCode.BadGateway)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 502. BadGateway indicates that an intermediate proxy server received a bad response from another proxy or the origin server.");

                return errorResponse;
            }

            /**
            * Code   => 400
            * Status => HttpStatusCode.BadRequest
            */
            if (response.StatusCode == HttpStatusCode.BadRequest)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 400. BadRequest indicates that the request could not be understood by the server. BadRequest is sent when no other error is applicable, or if the exact error is unknown or does not have its own error code.");

                return errorResponse;
            }

            /**
            * Code   => 409
            * Status => HttpStatusCode.Conflict
            */
            if (response.StatusCode == HttpStatusCode.Conflict)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 409. Conflict indicates that the request could not be carried out because of a conflict on the server.");

                return errorResponse;
            }

            /**
            * Code   => 100
            * Status => HttpStatusCode.Continue
            */
            if (response.StatusCode == HttpStatusCode.Continue)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 100. Continue indicates that the client can continue with its request.");

                return errorResponse;
            }

            /**
            * Code   => 201
            * Status => HttpStatusCode.Created
            */
            if (response.StatusCode == HttpStatusCode.Created)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 201. Created indicates that the request resulted in a new resource created before the response was sent.");

                return errorResponse;
            }

            /**
            * Code   => 417
            * Status => HttpStatusCode.ExpectationFailed
            */
            if (response.StatusCode == HttpStatusCode.ExpectationFailed)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 417. ExpectationFailed indicates that an expectation given in an Expect header could not be met by the server.");

                return errorResponse;
            }

            /**
            * Code   => 403
            * Status => HttpStatusCode.Forbidden
            */
            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 403. Forbidden indicates that the server refuses to fulfill the request.");

                return errorResponse;
            }

            /**
            * Code   => 302
            * Status => HttpStatusCode.Found
            */
            if (response.StatusCode == HttpStatusCode.Found)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 302. Found indicates that the requested information is located at the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. When the original request method was POST, the redirected request will use the GET method. Found is a synonym for Redirect.");

                return errorResponse;
            }

            /**
            * Code   => 504
            * Status => HttpStatusCode.GatewayTimeout
            */
            if (response.StatusCode == HttpStatusCode.GatewayTimeout)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 504. GatewayTimeout indicates that an intermediate proxy server timed out while waiting for a response from another proxy or the origin server.");

                return errorResponse;
            }

            /**
            * Code   => 410
            * Status => HttpStatusCode.Gone
            */
            if (response.StatusCode == HttpStatusCode.Gone)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 410. Gone indicates that the requested resource is no longer available.");

                return errorResponse;
            }

            /**
            * Code   => 505
            * Status => HttpStatusCode.HttpVersionNotSupported
            */
            if (response.StatusCode == HttpStatusCode.HttpVersionNotSupported)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 505. HttpVersionNotSupported indicates that the requested HTTP version is not supported by the server.");

                return errorResponse;
            }

            /**
            * Code   => 500
            * Status => HttpStatusCode.InternalServerError
            */
            if (response.StatusCode == HttpStatusCode.InternalServerError)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 500. InternalServerError indicates that a generic error has occurred on the server.");

                return errorResponse;
            }

            /**
            * Code   => 411
            * Status => HttpStatusCode.LengthRequired
            */
            if (response.StatusCode == HttpStatusCode.LengthRequired)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 411. LengthRequired indicates that the required Content-length header is missing.");

                return errorResponse;
            }

            /**
            * Code   => 405
            * Status => HttpStatusCode.MethodNotAllowed
            */
            if (response.StatusCode == HttpStatusCode.MethodNotAllowed)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 405. MethodNotAllowed indicates that the request method (POST or GET) is not allowed on the requested resource.");

                return errorResponse;
            }

            /**
            * Code   => 301
            * Status => HttpStatusCode.Moved
            */
            if (response.StatusCode == HttpStatusCode.Moved)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 301. Moved indicates that the requested information has been moved to the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. When the original request method was POST, the redirected request will use the GET method. Moved is a synonym for MovedPermanently.");

                return errorResponse;
            }

            /**
            * Code   => 301
            * Status => HttpStatusCode.MovedPermanently
            */
            if (response.StatusCode == HttpStatusCode.MovedPermanently)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 301. MovedPermanently indicates that the requested information has been moved to the URI specified in the Location header. The default action when this status is received is to follow the Location header associated with the response. MovedPermanently is a synonym for Moved.");

                return errorResponse;
            }

            /**
            * Code   => 300
            * Status => HttpStatusCode.MultipleChoices
            */
            if (response.StatusCode == HttpStatusCode.MultipleChoices)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 300. MultipleChoices indicates that the requested information has multiple representations. The default action is to treat this status as a redirect and follow the contents of the Location header associated with this response. MultipleChoices is a synonym for Ambiguous.");

                return errorResponse;
            }

            /**
            * Code   => 204
            * Status => HttpStatusCode.NoContent
            */
            if (response.StatusCode == HttpStatusCode.NoContent)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 204. NoContent indicates that the request has been successfully processed and that the response is intentionally blank.");

                return errorResponse;
            }

            /**
            * Code   => 203
            * Status => HttpStatusCode.NonAuthoritativeInformation
            */
            if (response.StatusCode == HttpStatusCode.NonAuthoritativeInformation)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 203. NonAuthoritativeInformation indicates that the returned metainformation is from a cached copy instead of the origin server and therefore may be incorrect.");

                return errorResponse;
            }

            /**
            * Code   => 406
            * Status => HttpStatusCode.NotAcceptable
            */
            if (response.StatusCode == HttpStatusCode.NotAcceptable)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 406. NotAcceptable indicates that the client has indicated with Accept headers that it will not accept any of the available representations of the resource.");

                return errorResponse;
            }

            /**
            * Code   => 404
            * Status => HttpStatusCode.NotFound
            */
            if (response.StatusCode == HttpStatusCode.NotFound)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 404. NotFound indicates that the requested resource does not exist on the server.");

                return errorResponse;
            }

            /**
            * Code   => 501
            * Status => HttpStatusCode.NotImplemented
            */
            if (response.StatusCode == HttpStatusCode.NotImplemented)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 501. NotImplemented indicates that the server does not support the requested function.");

                return errorResponse;
            }

            /**
            * Code   => 304
            * Status => HttpStatusCode.NotModified
            */
            if (response.StatusCode == HttpStatusCode.NotModified)
            {
                request.Properties.Remove(HttpPropertyKeys.NoRouteMatched);
                var errorResponse = request.CreateErrorResponse(response.StatusCode,
                                        "Equivalent to HTTP status 304. NotModified indicates that the client's cached copy is up to date. The contents of the resource are not transferred.");

                return errorResponse;
            }

            return response;
        }
    }
}
