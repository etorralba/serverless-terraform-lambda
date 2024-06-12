import {
    APIGatewayProxyEventV2,
    APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import base64 from "base-64";
import { printValue } from "../src/test_function";

export const handler = async (
    event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyStructuredResultV2> => {
    const body = JSON.parse(base64.decode(event.body!));
    printValue(body);
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "This is function2",
        }),
    };
};