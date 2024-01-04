import { FC } from "react";
import { Alert, Button, Group, Modal } from "@mantine/core";
import { IconZoomCheck } from "@tabler/icons-react";
import { useDisclosure, useLocalStorage } from "@mantine/hooks";

const Disclaimer: FC = () => {
  const [showDisclaimer, setShowDisclaimer] = useLocalStorage({
    key: "showDisclaimer",
    defaultValue: true,
    serialize: (value) => (value ? "true" : "false"),
    deserialize: (value) => value === "true",
  });

  const [opened, { open, close }] = useDisclosure(false);

  if (!showDisclaimer) {
    return null;
  }

  return (
    <>
      <Modal opened={opened} onClose={close} title="Dölj" withCloseButton centered>
        <p>Du kommer inte visas varningstexten igen. Är du säker på att du läst den?</p>
        <Group grow>
          <Button
            variant="outline"
            onClick={() => {
              close();
              setShowDisclaimer(false);
            }}
          >
            Ja
          </Button>
          <Button data-autofocus onClick={close}>
            Nej
          </Button>
        </Group>
      </Modal>
      <Alert
        variant="light"
        color="yellow"
        title="Observera"
        icon={<IconZoomCheck />}
        withCloseButton
        onClose={open}
        mb="md"
      >
        <p>
          Kom ihåg att inte alla datakällor är tillförlitliga, även om den kan tillhandahållas från en i övrigt
          officiell och tillförlitlig organisation som en myndighet.
        </p>
        <p>
          Denna sida tar inget ansvar för korrektheten på det data som visas här. Fundera alltid på om det som anges är
          rimligt och stämmer med t.ex. flygfoton. Ändra inget i OSM om du är osäker.
        </p>
      </Alert>
    </>
  );
};
export default Disclaimer;
