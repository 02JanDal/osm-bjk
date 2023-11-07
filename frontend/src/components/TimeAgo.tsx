import strings from "react-timeago/lib/language-strings/sv";
import buildFormatter from "react-timeago/lib/formatters/buildFormatter";
import ReactTimeago from "react-timeago";
import { FC } from "react";

const formatter = buildFormatter(strings);

const TimeAgo: FC<ReactTimeago.ReactTimeagoProps> = (props) => <ReactTimeago {...props} formatter={formatter} />;
export default TimeAgo;
